public with sharing class DashboardController {

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

    public class DashboardData {
        @AuraEnabled public Integer totalActive = 0;
        @AuraEnabled public Decimal avgBurnout = 0;
        @AuraEnabled public Integer burnoutHigh = 0;
        @AuraEnabled public Integer attritionHigh = 0;
        @AuraEnabled public Integer promotionReady = 0;
        @AuraEnabled public Map<String, Integer> burnoutLevels = new Map<String, Integer>();
        @AuraEnabled public Map<String, Integer> attritionLevels = new Map<String, Integer>();
        @AuraEnabled public List<DeptStat> departments = new List<DeptStat>();
        @AuraEnabled public List<Employee__c> topBurnout = new List<Employee__c>();
        @AuraEnabled public List<Employee__c> topPromotion = new List<Employee__c>();
    }

    @AuraEnabled(cacheable=true)
    public static DashboardData getDashboard() {

        if (!Schema.sObjectType.Employee__c.fields.Burnout_Score__c.isAccessible()) {
            throw new AuraHandledException('You do not have access to workforce scores.');
        }

        DashboardData d = new DashboardData();

        for (String l : new List<String>{ 'Low', 'Medium', 'High', 'Critical', 'Not Calculated' }) {
            d.burnoutLevels.put(l, 0);
        }

        for (String l : new List<String>{ 'Low', 'Medium', 'High', 'Not Calculated' }) {
            d.attritionLevels.put(l, 0);
        }

        Map<String, DeptStat> byDept = new Map<String, DeptStat>();
        Decimal sum = 0;
        Integer n = 0;

        for (Employee__c e : [
            SELECT Id, Department__r.Name, Burnout_Score__c, Burnout_Level__c,
                   Attrition_Level__c, Promotion_Score__c
            FROM Employee__c
            WHERE Employment_Status__c = 'Active'
            LIMIT 5000
        ]) {

            d.totalActive++;

            String bl = e.Burnout_Level__c;
            String al = e.Attrition_Level__c;

            bump(d.burnoutLevels, bl);
            bump(d.attritionLevels, al);

            if (bl == 'High' || bl == 'Critical') {
                d.burnoutHigh++;
            }

            if (al == 'High') {
                d.attritionHigh++;
            }

            if (e.Promotion_Score__c != null && e.Promotion_Score__c >= 70) {
                d.promotionReady++;
            }

            String dn = (e.Department__r == null)
                ? 'No department'
                : e.Department__r.Name;

            DeptStat s = byDept.get(dn);

            if (s == null) {
                s = new DeptStat();
                s.department = dn;
                byDept.put(dn, s);
            }

            s.headcount++;

            if (bl == 'Low') {
                s.low++;
            }
            else if (bl == 'Medium') {
                s.medium++;
            }
            else if (bl == 'High') {
                s.high++;
            }
            else if (bl == 'Critical') {
                s.critical++;
            }

            if (e.Burnout_Score__c != null) {
                s.burnoutTotal += e.Burnout_Score__c;
                s.scored++;
                sum += e.Burnout_Score__c;
                n++;
            }
        }

        d.avgBurnout = (n > 0) ? (sum / n).setScale(1) : 0;

        List<String> names = new List<String>(byDept.keySet());
        names.sort();

        for (String name : names) {
            DeptStat s = byDept.get(name);

            s.avgBurnout = (s.scored > 0)
                ? (s.burnoutTotal / s.scored).setScale(1)
                : 0;

            d.departments.add(s);
        }

        d.topBurnout = [
            SELECT Id, Name, Department__r.Name, Burnout_Score__c,
                   Total_Overtime_30d__c, Weekend_Days_30d__c
            FROM Employee__c
            WHERE Employment_Status__c = 'Active'
            AND Burnout_Score__c >= 70
            ORDER BY Burnout_Score__c DESC
            LIMIT 5
        ];

        d.topPromotion = [
            SELECT Id, Name, Department__r.Name, Promotion_Score__c,
                   Performance_Score__c
            FROM Employee__c
            WHERE Employment_Status__c = 'Active'
            AND Promotion_Score__c >= 70
            ORDER BY Promotion_Score__c DESC
            LIMIT 5
        ];

        return d;
    }
    @AuraEnabled(cacheable=true)
    public static List<Employee__c> getMyTeam() {

        List<Employee__c> me = [
            SELECT Id
            FROM Employee__c
            WHERE User__c = :UserInfo.getUserId()
            LIMIT 1
        ];

        if (me.isEmpty()) {
            return new List<Employee__c>();
        }

        List<Employee__c> team = [
            SELECT Id, Name, Department__r.Name, Burnout_Score__c, Burnout_Level__c,
                   Promotion_Score__c, Attrition_Score__c, Attrition_Level__c,
                   Total_Overtime_30d__c, Weekend_Days_30d__c
            FROM Employee__c
            WHERE Manager__c = :me[0].Id
            AND Employment_Status__c != 'Exited'
            ORDER BY Burnout_Score__c DESC NULLS LAST
        ];

        if (team.isEmpty()) {
            return team;
        }

        return (List<Employee__c>) Security.stripInaccessible(
            AccessType.READABLE, team
        ).getRecords();
    }

    private static void bump(Map<String, Integer> m, String key) {
        if (key != null && m.containsKey(key)) {
            m.put(key, m.get(key) + 1);
        }
    }
}