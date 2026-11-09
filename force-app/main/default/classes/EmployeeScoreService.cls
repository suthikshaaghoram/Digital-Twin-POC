public without sharing class EmployeeScoreService
    implements Database.Batchable<SObject>, Schedulable {

    // ---------------- Tuning constants (change here to tune the scoring) ----------------
    // Burnout (weights add up to 100)
    private static final Decimal OVERTIME_CAP = 50;       // overtime hours in 30 days = 100 points
    private static final Decimal WEEKEND_CAP = 6;         // weekend days worked in 30 days = 100 points
    private static final Decimal NO_LEAVE_CAP = 120;      // days since last leave = 100 points
    private static final Decimal W_BURN_OVERTIME = 50;
    private static final Decimal W_BURN_NO_LEAVE = 30;
    private static final Decimal W_BURN_WEEKEND = 20;
    // Promotion (weights add up to 100)
    private static final Decimal CERT_CAP = 3;            // active certifications = 100 points
    private static final Decimal W_PROMO_REVIEW = 50;
    private static final Decimal W_PROMO_GOALS = 25;
    private static final Decimal W_PROMO_CERTS = 25;
    // Attrition (weights add up to 100)
    private static final Decimal FEEDBACK_BASELINE = 4.5; // ratings below this add risk
    private static final Decimal FEEDBACK_SPAN = 3;       // 3 points below the baseline = 100 points
    private static final Decimal LEAVE_CAP = 25;          // leave days this year = 100 points
    private static final Decimal W_ATTR_FEEDBACK = 50;
    private static final Decimal W_ATTR_GOALS = 30;
    private static final Decimal W_ATTR_LEAVE = 20;

    // ---------------- Main calculation ----------------
    public static void calculate(Set<Id> employeeIds) {
        if (employeeIds == null || employeeIds.isEmpty()) { return; }
        Date today = Date.today();
        Date windowStart = today.addDays(-29);

        // 1. Attendance (last 30 days): overtime hours and weekend days worked
        Map<Id, Decimal> overtime = new Map<Id, Decimal>();
        Map<Id, Integer> weekendDays = new Map<Id, Integer>();
        for (Attendance__c a : [SELECT Employee__c, Overtime_Hours__c, Is_Weekend__c, Status__c
                                FROM Attendance__c
                                WHERE Employee__c IN :employeeIds
                                AND Date__c >= :windowStart AND Date__c <= :today]) {
            overtime.put(a.Employee__c, nz(overtime.get(a.Employee__c)) + nz(a.Overtime_Hours__c));
            if (a.Is_Weekend__c == true && (a.Status__c == 'Present' || a.Status__c == 'WFH')) {
                Integer w = weekendDays.containsKey(a.Employee__c) ? weekendDays.get(a.Employee__c) : 0;
                weekendDays.put(a.Employee__c, w + 1);
            }
        }

        // 2. Date of the last approved leave (Work From Home does not count as leave)
        Map<Id, Date> lastLeave = new Map<Id, Date>();
        for (AggregateResult ar : [SELECT Employee__c emp, MAX(End_Date__c) lastEnd
                                   FROM Leave__c
                                   WHERE Employee__c IN :employeeIds AND Status__c = 'Approved'
                                   AND Leave_Type__c != 'Work From Home' AND End_Date__c <= :today
                                   GROUP BY Employee__c]) {
            lastLeave.put((Id) ar.get('emp'), (Date) ar.get('lastEnd'));
        }

        // 3. Active certifications (not expired)
        Map<Id, Integer> certs = new Map<Id, Integer>();
        for (AggregateResult ar : [SELECT Employee__c emp, COUNT(Id) c
                                   FROM Certification__c
                                   WHERE Employee__c IN :employeeIds
                                   AND (Expiry_Date__c = null OR Expiry_Date__c >= :today)
                                   GROUP BY Employee__c]) {
            certs.put((Id) ar.get('emp'), (Integer) ar.get('c'));
        }

        // 4. Average of the latest 4 finalised reviews (1 to 5 scale)
        Map<Id, Decimal> reviewSum = new Map<Id, Decimal>();
        Map<Id, Integer> reviewCount = new Map<Id, Integer>();
        for (Performance_Review__c r : [SELECT Employee__c, Overall_Score__c
                                        FROM Performance_Review__c
                                        WHERE Employee__c IN :employeeIds AND Status__c = 'Finalised'
                                        AND Overall_Score__c != null
                                        ORDER BY Review_Year__c DESC, Review_Quarter__c DESC]) {
            Integer n = reviewCount.containsKey(r.Employee__c) ? reviewCount.get(r.Employee__c) : 0;
            if (n >= 4) { continue; }
            reviewSum.put(r.Employee__c, nz(reviewSum.get(r.Employee__c)) + r.Overall_Score__c);
            reviewCount.put(r.Employee__c, n + 1);
        }

        // 5. Goal achievement (goals due in the last year, or already achieved)
        Date goalStart = today.addDays(-365);
        Map<Id, Decimal> goalSum = new Map<Id, Decimal>();
        Map<Id, Integer> goalCount = new Map<Id, Integer>();
        for (Goal__c g : [SELECT Employee__c, Target_Value__c, Actual_Value__c
                          FROM Goal__c
                          WHERE Employee__c IN :employeeIds AND Target_Value__c > 0
                          AND Deadline__c >= :goalStart
                          AND (Deadline__c <= :today OR Status__c = 'Achieved')]) {
            Decimal pct = (nz(g.Actual_Value__c) * 100).divide(g.Target_Value__c, 2);
            if (pct > 100) { pct = 100; }
            goalSum.put(g.Employee__c, nz(goalSum.get(g.Employee__c)) + pct);
            Integer c = goalCount.containsKey(g.Employee__c) ? goalCount.get(g.Employee__c) : 0;
            goalCount.put(g.Employee__c, c + 1);
        }

        // 6. Calculate the three scores and save only what changed
        List<Employee__c> updates = new List<Employee__c>();
        for (Employee__c e : [SELECT Id, Joining_Date__c, Avg_Feedback_Rating__c, Leave_Days_YTD__c,
                                     Burnout_Score__c, Promotion_Score__c, Attrition_Score__c,
                                     Total_Overtime_30d__c, Weekend_Days_30d__c
                              FROM Employee__c WHERE Id IN :employeeIds]) {
            Decimal ot = nz(overtime.get(e.Id));
            Integer wk = weekendDays.containsKey(e.Id) ? weekendDays.get(e.Id) : 0;

            Integer daysSinceLeave = 365;
            if (lastLeave.containsKey(e.Id) && lastLeave.get(e.Id) != null) {
                daysSinceLeave = lastLeave.get(e.Id).daysBetween(today);
            } else if (e.Joining_Date__c != null) {
                daysSinceLeave = e.Joining_Date__c.daysBetween(today);
            }

            Decimal reviewAvg = reviewCount.containsKey(e.Id)
                ? reviewSum.get(e.Id).divide(reviewCount.get(e.Id), 2) : null;
            Decimal goalPct = goalCount.containsKey(e.Id)
                ? goalSum.get(e.Id).divide(goalCount.get(e.Id), 2) : null;
            Integer activeCerts = certs.containsKey(e.Id) ? certs.get(e.Id) : 0;

            // Burnout
            Decimal burnout = (norm(ot, OVERTIME_CAP) * W_BURN_OVERTIME
                + norm(daysSinceLeave, NO_LEAVE_CAP) * W_BURN_NO_LEAVE
                + norm(wk, WEEKEND_CAP) * W_BURN_WEEKEND) / 100;

            // Promotion (missing data counts as 0: no evidence means not ready)
            Decimal promotion = (norm(reviewAvg, 5) * W_PROMO_REVIEW
                + norm(goalPct, 100) * W_PROMO_GOALS
                + norm(activeCerts, CERT_CAP) * W_PROMO_CERTS) / 100;

            // Attrition (missing feedback or goals counts as neutral = 50)
            Decimal feedbackRisk = (e.Avg_Feedback_Rating__c == null)
                ? 50 : norm(FEEDBACK_BASELINE - e.Avg_Feedback_Rating__c, FEEDBACK_SPAN);
            Decimal goalRisk = (goalPct == null) ? 50 : norm(100 - goalPct, 100);
            Decimal attrition = (feedbackRisk * W_ATTR_FEEDBACK
                + goalRisk * W_ATTR_GOALS
                + norm(e.Leave_Days_YTD__c, LEAVE_CAP) * W_ATTR_LEAVE) / 100;

            Employee__c upd = new Employee__c(Id = e.Id);
            Boolean dirty = false;
            if (changed(e.Burnout_Score__c, burnout)) { upd.Burnout_Score__c = round2(burnout); dirty = true; }
            if (changed(e.Promotion_Score__c, promotion)) { upd.Promotion_Score__c = round2(promotion); dirty = true; }
            if (changed(e.Attrition_Score__c, attrition)) { upd.Attrition_Score__c = round2(attrition); dirty = true; }
            if (changed(e.Total_Overtime_30d__c, ot)) { upd.Total_Overtime_30d__c = round2(ot); dirty = true; }
            if (changed(e.Weekend_Days_30d__c, wk)) { upd.Weekend_Days_30d__c = wk; dirty = true; }
            if (dirty) {
                upd.Last_Score_Date__c = System.now();
                updates.add(upd);
            }
        }

        if (!updates.isEmpty()) {
            for (Database.SaveResult r : Database.update(updates, false)) {
                if (!r.isSuccess()) {
                    System.debug(LoggingLevel.ERROR, 'EmployeeScoreService: ' + r.getErrors()[0].getMessage());
                }
            }
        }
    }

    // ---------------- Helpers ----------------
    private static Decimal nz(Decimal v) { return (v == null) ? 0 : v; }

    // Converts a raw value to 0..100, where 'cap' is the value that equals 100
    private static Decimal norm(Decimal value, Decimal cap) {
        if (value == null || value <= 0 || cap == null || cap <= 0) { return 0; }
        if (value >= cap) { return 100; }
        return value.divide(cap, 4) * 100;
    }

    private static Decimal round2(Decimal v) { return v.setScale(2, RoundingMode.HALF_UP); }

    private static Boolean changed(Decimal oldVal, Decimal newVal) {
        return oldVal == null || Math.abs(oldVal - newVal) >= 0.01;
    }

    // ---------------- Run for all active employees (batch) ----------------
    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id FROM Employee__c WHERE Employment_Status__c != 'Exited'
        ]);
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        calculate(new Map<Id, SObject>(scope).keySet());
    }

    public void finish(Database.BatchableContext bc) {
        System.debug('EmployeeScoreService batch finished: ' + bc.getJobId());
    }

    // ---------------- Schedule nightly ----------------
    public void execute(SchedulableContext sc) {
        Database.executeBatch(new EmployeeScoreService(), 100);
    }

    // ---------------- Optional: call from a Flow ----------------
    @InvocableMethod(label='Recalculate Employee Scores' category='Digital Twin')
    public static void recalculate(List<Id> employeeIds) {
        calculate(new Set<Id>(employeeIds));
    }
}