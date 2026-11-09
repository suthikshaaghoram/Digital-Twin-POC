public with sharing class HrDashboardController {
 
    private static final Decimal RISK_THRESHOLD      = 70;
    private static final Decimal CRITICAL_THRESHOLD  = 85;
    private static final Decimal PROMOTION_THRESHOLD = 90;
    private static final Integer CERT_WINDOW_DAYS    = 60;
    private static final Integer WATCHLIST_LIMIT     = 25;
 
    public class DeptOption {
        @AuraEnabled public String value;
        @AuraEnabled public String label;
    }
 
    public class DeptStat {
        @AuraEnabled public String department;
        @AuraEnabled public Integer headcount = 0;
        @AuraEnabled public Integer low = 0;
        @AuraEnabled public Integer medium = 0;
        @AuraEnabled public Integer high = 0;
        @AuraEnabled public Integer critical = 0;
        @AuraEnabled public Decimal avgBurnout = 0;
        Decimal burnoutTotal = 0;
        Integer scored = 0;
    }
 
    public class WatchRow implements Comparable {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String department;
        @AuraEnabled public String manager;
        @AuraEnabled public Decimal burnout;
        @AuraEnabled public Decimal attrition;
        @AuraEnabled public Decimal promotion;
        @AuraEnabled public Decimal overtime;
        @AuraEnabled public Decimal weekendDays;
        @AuraEnabled public String flags;
        @AuraEnabled public String suggestedAction;
        @AuraEnabled public Boolean isBurnout = false;
        @AuraEnabled public Boolean isAttrition = false;
        @AuraEnabled public Boolean isPromotion = false;
        @AuraEnabled public Decimal severity = 0;
 
        public Integer compareTo(Object other) {
            WatchRow o = (WatchRow) other;
            if (severity == o.severity) { return 0; }
            return (severity > o.severity) ? -1 : 1;
        }
    }
 
    public class TaskItem {
        @AuraEnabled public Id id;
        @AuraEnabled public String subject;
        @AuraEnabled public Id relatedId;
        @AuraEnabled public String relatedName;
        @AuraEnabled public String priority;
        @AuraEnabled public String status;
        @AuraEnabled public Date dueDate;
        @AuraEnabled public String owner;
        @AuraEnabled public Boolean overdue = false;
    }
 
    public class WorkItem {
        @AuraEnabled public Id id;
        @AuraEnabled public Id employeeId;
        @AuraEnabled public String employeeName;
        @AuraEnabled public String title;
        @AuraEnabled public String detail;
        @AuraEnabled public Date dueDate;
        @AuraEnabled public String status;
    }
 
    public class JobInfo {
        @AuraEnabled public String status;
        @AuraEnabled public Integer processed;
        @AuraEnabled public Integer total;
        @AuraEnabled public Integer errors;
    }
 
    public class HrDashboardData {
        @AuraEnabled public Integer totalActive = 0;
        @AuraEnabled public Decimal avgBurnout = 0;
        @AuraEnabled public Integer burnoutHigh = 0;
        @AuraEnabled public Integer attritionHigh = 0;
        @AuraEnabled public Integer promotionReady = 0;
        @AuraEnabled public Integer openTaskCount = 0;
        @AuraEnabled public Integer overdueTaskCount = 0;
        @AuraEnabled public Integer certExpiringCount = 0;
        @AuraEnabled public Integer trainingOverdueCount = 0;
        @AuraEnabled public Integer pendingLeaveCount = 0;
        @AuraEnabled public Datetime lastScoreDate;
        @AuraEnabled public Boolean canRefreshScores = false;
        @AuraEnabled public Map<String, Integer> burnoutLevels = new Map<String, Integer>();
        @AuraEnabled public Map<String, Integer> attritionLevels = new Map<String, Integer>();
        @AuraEnabled public List<DeptStat> departments = new List<DeptStat>();
        @AuraEnabled public List<WatchRow> watchlist = new List<WatchRow>();
        @AuraEnabled public List<TaskItem> tasks = new List<TaskItem>();
        @AuraEnabled public List<WorkItem> certs = new List<WorkItem>();
        @AuraEnabled public List<WorkItem> trainings = new List<WorkItem>();
        @AuraEnabled public List<WorkItem> leaves = new List<WorkItem>();
    }
 
    @AuraEnabled(cacheable=true)
    public static List<DeptOption> getDepartments() {
        List<DeptOption> out = new List<DeptOption>();
        for (Department__c dep : [SELECT Id, Name FROM Department__c ORDER BY Name LIMIT 200]) {
            DeptOption o = new DeptOption();
            o.value = dep.Id;
            o.label = dep.Name;
            out.add(o);
        }
        return out;
    }
 
    @AuraEnabled(cacheable=true)
    public static HrDashboardData getHrDashboard(Id departmentId) {
        if (!Schema.sObjectType.Employee__c.fields.Burnout_Score__c.isAccessible()) {
            throw new AuraHandledException('You do not have access to workforce scores.');
        }
 
        HrDashboardData d = new HrDashboardData();
        d.canRefreshScores = Schema.sObjectType.Employee__c.fields.Burnout_Score__c.isUpdateable();
        for (String l : new List<String>{ 'Low', 'Medium', 'High', 'Critical', 'Not Calculated' }) {
            d.burnoutLevels.put(l, 0);
        }
        for (String l : new List<String>{ 'Low', 'Medium', 'High', 'Not Calculated' }) {
            d.attritionLevels.put(l, 0);
        }
 
        Date today = Date.today();
        Date soon = today.addDays(CERT_WINDOW_DAYS);
 
        List<Employee__c> emps;
        if (departmentId == null) {
            emps = [
                SELECT Id, Name, Department__r.Name, Manager__r.Name,
                       Burnout_Score__c, Burnout_Level__c, Attrition_Score__c, Attrition_Level__c,
                       Promotion_Score__c, Performance_Score__c,
                       Total_Overtime_30d__c, Weekend_Days_30d__c, Last_Score_Date__c
                FROM Employee__c
                WHERE Employment_Status__c = 'Active'
                LIMIT 5000
            ];
        } else {
            emps = [
                SELECT Id, Name, Department__r.Name, Manager__r.Name,
                       Burnout_Score__c, Burnout_Level__c, Attrition_Score__c, Attrition_Level__c,
                       Promotion_Score__c, Performance_Score__c,
                       Total_Overtime_30d__c, Weekend_Days_30d__c, Last_Score_Date__c
                FROM Employee__c
                WHERE Employment_Status__c = 'Active' AND Department__c = :departmentId
                LIMIT 5000
            ];
        }
 
        Map<String, DeptStat> byDept = new Map<String, DeptStat>();
        List<WatchRow> watch = new List<WatchRow>();
        Decimal sum = 0;
        Integer n = 0;
 
        for (Employee__c e : emps) {
            d.totalActive++;
            String bl = e.Burnout_Level__c;
            String al = e.Attrition_Level__c;
            bump(d.burnoutLevels, bl);
            bump(d.attritionLevels, al);
            if (bl == 'High' || bl == 'Critical') { d.burnoutHigh++; }
            if (al == 'High') { d.attritionHigh++; }
            if (e.Promotion_Score__c != null && e.Promotion_Score__c >= PROMOTION_THRESHOLD) {
                d.promotionReady++;
            }
            if (e.Last_Score_Date__c != null
                && (d.lastScoreDate == null || e.Last_Score_Date__c > d.lastScoreDate)) {
                d.lastScoreDate = e.Last_Score_Date__c;
            }
 
            String dn = (e.Department__r == null) ? 'No department' : e.Department__r.Name;
            DeptStat s = byDept.get(dn);
            if (s == null) {
                s = new DeptStat();
                s.department = dn;
                byDept.put(dn, s);
            }
            s.headcount++;
            if (bl == 'Low') { s.low++; }
            else if (bl == 'Medium') { s.medium++; }
            else if (bl == 'High') { s.high++; }
            else if (bl == 'Critical') { s.critical++; }
            if (e.Burnout_Score__c != null) {
                s.burnoutTotal += e.Burnout_Score__c;
                s.scored++;
                sum += e.Burnout_Score__c;
                n++;
            }
 
            WatchRow w = toWatchRow(e);
            if (w != null) { watch.add(w); }
        }
 
        d.avgBurnout = (n > 0) ? (sum / n).setScale(1) : 0;
 
        List<String> names = new List<String>(byDept.keySet());
        names.sort();
        for (String name : names) {
            DeptStat s = byDept.get(name);
            s.avgBurnout = (s.scored > 0) ? (s.burnoutTotal / s.scored).setScale(1) : 0;
            d.departments.add(s);
        }
 
        watch.sort();
        for (Integer i = 0; i < watch.size() && i < WATCHLIST_LIMIT; i++) {
            d.watchlist.add(watch[i]);
        }
 
        if (emps.isEmpty()) { return d; }
        Set<Id> empIds = new Map<Id, Employee__c>(emps).keySet();
 
        d.openTaskCount = [SELECT COUNT() FROM Task
                           WHERE IsClosed = false AND What.Type = 'Employee__c' AND WhatId IN :empIds];
        d.overdueTaskCount = [SELECT COUNT() FROM Task
                              WHERE IsClosed = false AND What.Type = 'Employee__c' AND WhatId IN :empIds
                              AND ActivityDate < :today];
        d.certExpiringCount = [SELECT COUNT() FROM Certification__c
                               WHERE Employee__c IN :empIds
                               AND Expiry_Date__c >= :today AND Expiry_Date__c <= :soon];
        d.trainingOverdueCount = [SELECT COUNT() FROM Training__c
                                  WHERE Employee__c IN :empIds AND Status__c = 'Overdue'];
        d.pendingLeaveCount = [SELECT COUNT() FROM Leave__c
                               WHERE Employee__c IN :empIds AND Status__c = 'Pending'];
 
        for (Task t : [SELECT Id, Subject, Priority, Status, ActivityDate, WhatId, What.Name, Owner.Name
                       FROM Task
                       WHERE IsClosed = false AND What.Type = 'Employee__c' AND WhatId IN :empIds
                       ORDER BY ActivityDate ASC NULLS LAST
                       LIMIT 10]) {
            TaskItem ti = new TaskItem();
            ti.id = t.Id;
            ti.subject = t.Subject;
            ti.relatedId = t.WhatId;
            ti.relatedName = (t.What == null) ? null : t.What.Name;
            ti.priority = t.Priority;
            ti.status = t.Status;
            ti.dueDate = t.ActivityDate;
            ti.owner = (t.Owner == null) ? null : t.Owner.Name;
            ti.overdue = (t.ActivityDate != null && t.ActivityDate < today);
            d.tasks.add(ti);
        }
 
        for (Certification__c c : [SELECT Id, Employee__c, Employee__r.Name, Name, Expiry_Date__c
                                   FROM Certification__c
                                   WHERE Employee__c IN :empIds
                                   AND Expiry_Date__c >= :today AND Expiry_Date__c <= :soon
                                   ORDER BY Expiry_Date__c
                                   LIMIT 10]) {
            Integer left = today.daysBetween(c.Expiry_Date__c);
            WorkItem w = new WorkItem();
            w.id = c.Id;
            w.employeeId = c.Employee__c;
            w.employeeName = c.Employee__r.Name;
            w.title = c.Name;
            w.detail = 'Certification';
            w.dueDate = c.Expiry_Date__c;
            w.status = (left == 0) ? 'Expires today' : 'In ' + left + ' days';
            d.certs.add(w);
        }
 
        for (Training__c t : [SELECT Id, Employee__c, Employee__r.Name, Course__r.Name,
                                     Due_Date__c, Assigned_By__c
                              FROM Training__c
                              WHERE Employee__c IN :empIds AND Status__c = 'Overdue'
                              ORDER BY Due_Date__c
                              LIMIT 10]) {
            WorkItem w = new WorkItem();
            w.id = t.Id;
            w.employeeId = t.Employee__c;
            w.employeeName = t.Employee__r.Name;
            w.title = t.Course__r.Name;
            w.detail = 'Assigned by ' + (t.Assigned_By__c == null ? 'n/a' : t.Assigned_By__c);
            w.dueDate = t.Due_Date__c;
            w.status = (t.Due_Date__c == null)
                ? 'Overdue'
                : 'Overdue by ' + t.Due_Date__c.daysBetween(today) + ' days';
            d.trainings.add(w);
        }
 
        for (Leave__c l : [SELECT Id, Employee__c, Employee__r.Name, Leave_Type__c, Start_Date__c, Days__c
                           FROM Leave__c
                           WHERE Employee__c IN :empIds AND Status__c = 'Pending'
                           ORDER BY Start_Date__c
                           LIMIT 10]) {
            WorkItem w = new WorkItem();
            w.id = l.Id;
            w.employeeId = l.Employee__c;
            w.employeeName = l.Employee__r.Name;
            w.title = l.Leave_Type__c + ' leave';
            w.detail = (l.Days__c == null) ? '' : l.Days__c.stripTrailingZeros().toPlainString() + ' day(s)';
            w.dueDate = l.Start_Date__c;
            w.status = 'Pending approval';
            d.leaves.add(w);
        }
 
        return d;
    }
 
    @AuraEnabled
    public static void completeTask(Id taskId) {
        if (!Schema.sObjectType.Task.isUpdateable()) {
            throw new AuraHandledException('You cannot update tasks.');
        }
        try {
            Task t = [SELECT Id, Status FROM Task
                      WHERE Id = :taskId AND IsClosed = false AND What.Type = 'Employee__c'
                      LIMIT 1];
            t.Status = 'Completed';
            update t;
        } catch (QueryException qe) {
            throw new AuraHandledException('That task was not found or is already closed.');
        } catch (DmlException de) {
            throw new AuraHandledException(de.getDmlMessage(0));
        }
    }
 
    @AuraEnabled
    public static Id runScoreRefresh() {
        if (!Schema.sObjectType.Employee__c.fields.Burnout_Score__c.isUpdateable()) {
            throw new AuraHandledException('Only HR can recalculate scores.');
        }
        return Database.executeBatch(new EmployeeScoreService(), 100);
    }
 
    @AuraEnabled
    public static JobInfo getJobStatus(Id jobId) {
        JobInfo j = new JobInfo();
        List<AsyncApexJob> jobs = [
            SELECT Status, JobItemsProcessed, TotalJobItems, NumberOfErrors
            FROM AsyncApexJob WHERE Id = :jobId LIMIT 1
        ];
        if (jobs.isEmpty()) {
            j.status = 'Aborted';
            j.processed = 0; j.total = 0; j.errors = 0;
            return j;
        }
        j.status = jobs[0].Status;
        j.processed = jobs[0].JobItemsProcessed;
        j.total = jobs[0].TotalJobItems;
        j.errors = jobs[0].NumberOfErrors;
        return j;
    }
 
    private static WatchRow toWatchRow(Employee__c e) {
        Decimal b = e.Burnout_Score__c;
        Decimal a = e.Attrition_Score__c;
        Decimal p = e.Promotion_Score__c;
 
        Boolean burn = (b != null && b >= RISK_THRESHOLD);
        Boolean attr = (a != null && a >= RISK_THRESHOLD);
        Boolean promo = (p != null && p >= PROMOTION_THRESHOLD);
        if (!burn && !attr && !promo) { return null; }
 
        WatchRow w = new WatchRow();
        w.id = e.Id;
        w.name = e.Name;
        w.department = (e.Department__r == null) ? null : e.Department__r.Name;
        w.manager = (e.Manager__r == null) ? null : e.Manager__r.Name;
        w.burnout = b;
        w.attrition = a;
        w.promotion = p;
        w.overtime = e.Total_Overtime_30d__c;
        w.weekendDays = e.Weekend_Days_30d__c;
        w.isBurnout = burn;
        w.isAttrition = attr;
        w.isPromotion = promo;
 
        List<String> flags = new List<String>();
        if (burn) { flags.add(b >= CRITICAL_THRESHOLD ? 'Critical burnout' : 'High burnout'); }
        if (attr) { flags.add('High attrition risk'); }
        if (promo) { flags.add('Promotion ready'); }
        w.flags = String.join(flags, ', ');
 
        if (burn && b >= CRITICAL_THRESHOLD) { w.suggestedAction = 'Wellbeing check-in this week'; }
        else if (attr) { w.suggestedAction = 'Retention conversation with manager'; }
        else if (burn) { w.suggestedAction = 'Review workload with manager'; }
        else { w.suggestedAction = 'Start promotion review'; }
 
        Decimal risk = Math.max(b == null ? 0 : b, a == null ? 0 : a);
        w.severity = (burn || attr) ? risk : (p == null ? 0 : p / 2);
        return w;
    }
 
    private static void bump(Map<String, Integer> m, String key) {
        if (key != null && m.containsKey(key)) { m.put(key, m.get(key) + 1); }
    }
}