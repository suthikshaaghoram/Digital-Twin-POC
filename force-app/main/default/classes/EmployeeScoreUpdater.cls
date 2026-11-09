public class EmployeeScoreUpdater {

    public static void updateScores(Set<Id> employeeIds) {

        Date today = Date.today();
        Date days30Ago = today.addDays(-30);
        Date days45Ago = today.addDays(-45);
        Date days135Ago = today.addDays(-135);

        List<Employee__c> employees = [
            SELECT Id, Joining_Date__c, Experience_Years__c,
                   Burnout_Score__c, Promotion_Score__c,
                   Job_Role__r.Min_Experience_Years__c
            FROM Employee__c
            WHERE Id IN :employeeIds AND Employment_Status__c != 'Exited'
        ];

        List<AggregateResult> rows = [
            SELECT Employee__c emp, SUM(Overtime_Hours__c) val
            FROM Attendance__c
            WHERE Employee__c IN :employeeIds AND Date__c >= :days30Ago AND Date__c <= :today
            GROUP BY Employee__c
        ];
        Map<Id, Decimal> overtimeMap = toMap(rows);

        rows = [
            SELECT Employee__c emp, COUNT(Id) val
            FROM Attendance__c
            WHERE Employee__c IN :employeeIds AND Date__c >= :days30Ago AND Date__c <= :today
              AND Is_Weekend__c = true AND Login_Time__c != null
            GROUP BY Employee__c
        ];
        Map<Id, Decimal> weekendMap = toMap(rows);

        Map<Id, Date> lastLeaveMap = new Map<Id, Date>();
        List<AggregateResult> leaveRows = [
            SELECT Employee__c emp, MAX(End_Date__c) lastDate
            FROM Leave__c
            WHERE Employee__c IN :employeeIds AND Status__c = 'Approved' AND End_Date__c <= :today
            GROUP BY Employee__c
        ];
        for (AggregateResult row : leaveRows) {
            lastLeaveMap.put((Id) row.get('emp'), (Date) row.get('lastDate'));
        }

        rows = [
            SELECT Employee__c emp, AVG(Rating__c) val
            FROM Feedback__c
            WHERE Employee__c IN :employeeIds AND Feedback_Date__c >= :days45Ago
            GROUP BY Employee__c
        ];
        Map<Id, Decimal> recentFeedbackMap = toMap(rows);

        rows = [
            SELECT Employee__c emp, AVG(Rating__c) val
            FROM Feedback__c
            WHERE Employee__c IN :employeeIds AND Feedback_Date__c >= :days135Ago
              AND Feedback_Date__c < :days45Ago
            GROUP BY Employee__c
        ];
        Map<Id, Decimal> oldFeedbackMap = toMap(rows);

        rows = [
            SELECT Employee__c emp, AVG(Overall_Score__c) val
            FROM Performance_Review__c
            WHERE Employee__c IN :employeeIds AND Status__c = 'Finalised'
            GROUP BY Employee__c
        ];
        Map<Id, Decimal> reviewMap = toMap(rows);

        rows = [
            SELECT Employee__c emp, AVG(Achievement_Percent__c) val
            FROM Goal__c
            WHERE Employee__c IN :employeeIds
            GROUP BY Employee__c
        ];
        Map<Id, Decimal> goalMap = toMap(rows);

        rows = [
            SELECT Employee__c emp, AVG(Rating__c) val
            FROM Feedback__c
            WHERE Employee__c IN :employeeIds
            GROUP BY Employee__c
        ];
        Map<Id, Decimal> feedbackAvgMap = toMap(rows);

        rows = [
            SELECT Employee__c emp, COUNT(Id) val
            FROM Certification__c
            WHERE Employee__c IN :employeeIds AND (Expiry_Date__c = null OR Expiry_Date__c >= :today)
            GROUP BY Employee__c
        ];
        Map<Id, Decimal> certMap = toMap(rows);

        rows = [
            SELECT Employee__c emp, COUNT(Id) val
            FROM Training__c
            WHERE Employee__c IN :employeeIds
            GROUP BY Employee__c
        ];
        Map<Id, Decimal> trainingTotalMap = toMap(rows);

        rows = [
            SELECT Employee__c emp, COUNT(Id) val
            FROM Training__c
            WHERE Employee__c IN :employeeIds AND Status__c = 'Completed'
            GROUP BY Employee__c
        ];
        Map<Id, Decimal> trainingDoneMap = toMap(rows);

        List<Employee__c> employeesToUpdate = new List<Employee__c>();

        for (Employee__c emp : employees) {

            Decimal overtime = getValue(overtimeMap, emp.Id);
            Decimal weekendDays = getValue(weekendMap, emp.Id);

            Date lastLeaveDate = lastLeaveMap.get(emp.Id);
            if (lastLeaveDate == null) {
                lastLeaveDate = emp.Joining_Date__c;
            }
            Decimal daysSinceLeave = 0;
            if (lastLeaveDate != null) {
                daysSinceLeave = lastLeaveDate.daysBetween(today);
            }

            Decimal feedbackDrop = 0;
            if (recentFeedbackMap.containsKey(emp.Id) && oldFeedbackMap.containsKey(emp.Id)) {
                Decimal drop = oldFeedbackMap.get(emp.Id) - recentFeedbackMap.get(emp.Id);
                if (drop > 0) {
                    feedbackDrop = drop;
                }
            }

            Decimal burnout = ScoreCalculator.burnoutScore(overtime, weekendDays, daysSinceLeave, feedbackDrop);

            Decimal trainingPercent = 0;
            Decimal totalTraining = getValue(trainingTotalMap, emp.Id);
            if (totalTraining > 0) {
                trainingPercent = (getValue(trainingDoneMap, emp.Id) / totalTraining) * 100;
            }

            Decimal requiredYears = null;
            if (emp.Job_Role__r != null) {
                requiredYears = emp.Job_Role__r.Min_Experience_Years__c;
            }

            Decimal promotion = ScoreCalculator.promotionScore(
                getValue(reviewMap, emp.Id),
                getValue(goalMap, emp.Id),
                getValue(certMap, emp.Id),
                trainingPercent,
                getValue(feedbackAvgMap, emp.Id),
                emp.Experience_Years__c,
                requiredYears
            );

            if (emp.Burnout_Score__c != burnout || emp.Promotion_Score__c != promotion) {
                Employee__c updated = new Employee__c(Id = emp.Id);
                updated.Burnout_Score__c = burnout;
                updated.Promotion_Score__c = promotion;
                updated.Total_Overtime_30d__c = overtime;
                updated.Weekend_Days_30d__c = weekendDays;
                updated.Last_Score_Date__c = System.now();
                employeesToUpdate.add(updated);
            }
        }

        if (!employeesToUpdate.isEmpty()) {
            Database.update(employeesToUpdate, false);
        }
    }

    private static Map<Id, Decimal> toMap(List<AggregateResult> rows) {
        Map<Id, Decimal> result = new Map<Id, Decimal>();
        for (AggregateResult row : rows) {
            if (row.get('val') != null) {
                result.put((Id) row.get('emp'), Decimal.valueOf(String.valueOf(row.get('val'))));
            }
        }
        return result;
    }

    private static Decimal getValue(Map<Id, Decimal> valueMap, Id employeeId) {
        if (valueMap.containsKey(employeeId)) {
            return valueMap.get(employeeId);
        }
        return 0;
    }
}