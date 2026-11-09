public with sharing class EmployeeSelfServiceController {

    @AuraEnabled(cacheable=true)
    public static Employee__c getMyEmployee() {

        if (!Schema.sObjectType.Employee__c.isAccessible()) {
            throw new AuraHandledException(
                'You do not have permission to view your employee record.'
            );
        }

        List<Employee__c> employees = [
            SELECT Id,
                   Name,
                   Email__c,
                   Phone__c,
                   Work_Mode__c,
                   Employment_Status__c
            FROM Employee__c
            WHERE User__c = :UserInfo.getUserId()
            LIMIT 1
        ];

        if (employees.isEmpty()) {
            return null;
        }

        SObjectAccessDecision decision =
            Security.stripInaccessible(
                AccessType.READABLE,
                employees
            );

        return (Employee__c) decision.getRecords()[0];
    }

    @AuraEnabled
    public static void updateMyEmployee(
        String email,
        String phone
    ) {

        if (!Schema.sObjectType.Employee__c.isUpdateable()) {
            throw new AuraHandledException(
                'You do not have permission to update your employee record.'
            );
        }

        if (!Schema.sObjectType.Employee__c.fields.Email__c.isUpdateable() ||
            !Schema.sObjectType.Employee__c.fields.Phone__c.isUpdateable()) {

            throw new AuraHandledException(
                'You do not have permission to update these fields.'
            );
        }

        List<Employee__c> employees = [
            SELECT Id, Email__c, Phone__c
            FROM Employee__c
            WHERE User__c = :UserInfo.getUserId()
            LIMIT 1
        ];

        if (employees.isEmpty()) {
            throw new AuraHandledException(
                'Employee record not found.'
            );
        }

        Employee__c employee = employees[0];

        employee.Email__c = email;
        employee.Phone__c = phone;

        SObjectAccessDecision decision =
            Security.stripInaccessible(
                AccessType.UPDATABLE,
                new List<Employee__c>{ employee }
            );

        Employee__c safeEmployee =
            (Employee__c) decision.getRecords()[0];

        update safeEmployee;
    }
}