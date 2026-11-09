public with sharing class EmployeeScoreController {

    @AuraEnabled(cacheable=true)
    public static List<Employee__c> getEmployeeScores() {

        return [
            SELECT Id,
                   Name,
                   Department__r.Name,
                   Employment_Status__c,
                   Burnout_Score__c,
                   Burnout_Level__c,
                   Promotion_Score__c,
                   Attrition_Score__c,
                   Attrition_Level__c,
                   Performance_Score__c,
                   Total_Overtime_30d__c,
                   Weekend_Days_30d__c,
                   Last_Score_Date__c
            FROM Employee__c
            WHERE Employment_Status__c != 'Exited'
            WITH USER_MODE
            ORDER BY Burnout_Score__c DESC NULLS LAST
            LIMIT 200
        ];
    }

    @AuraEnabled
    public static void recalculateScores(List<Id> employeeIds) {

        if (employeeIds == null || employeeIds.isEmpty()) {
            return;
        }

        EmployeeScoreService.calculate(
            new Set<Id>(employeeIds)
        );
    }
}