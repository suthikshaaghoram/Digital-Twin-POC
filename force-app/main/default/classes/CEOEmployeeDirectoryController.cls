public with sharing class CEOEmployeeDirectoryController {

    public class EmployeeDirectoryResult {
        @AuraEnabled public List<Employee__c> employees { get; set; }
        @AuraEnabled public Integer totalRecords { get; set; }
        @AuraEnabled public Integer pageNumber { get; set; }
        @AuraEnabled public Integer pageSize { get; set; }
    }

    public class FilterOption {
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String value { get; set; }

        public FilterOption(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }

    private static void verifyCEOAccess() {
        if (!FeatureManagement.checkPermission('CEO')) {
            throw new AuraHandledException(
                'You are not authorized to access the CEO dashboard.'
            );
        }
    }

    @AuraEnabled(cacheable=true)
    public static EmployeeDirectoryResult getEmployees(
        String searchKey,
        String departmentId,
        String employmentStatus,
        Integer pageNumber,
        Integer pageSize
    ) {
        verifyCEOAccess();

        Integer currentPage = (pageNumber == null || pageNumber < 1)
            ? 1 : pageNumber;

        Integer recordsPerPage = (pageSize == null)
            ? 25 : Math.min(Math.max(pageSize, 1), 50);

        Integer offsetRows = (currentPage - 1) * recordsPerPage;

        String baseQuery = ' FROM Employee__c WHERE Id != null';
        Map<String, Object> binds = new Map<String, Object>();

        if (String.isNotBlank(searchKey)) {
            binds.put('searchPattern', '%' + searchKey.trim() + '%');

            baseQuery +=
                ' AND (Name LIKE :searchPattern' +
                ' OR Email__c LIKE :searchPattern' +
                ' OR Employee_ID__c LIKE :searchPattern)';
        }

        if (String.isNotBlank(departmentId)) {
            binds.put('departmentId', departmentId);
            baseQuery += ' AND Department__c = :departmentId';
        }

        if (String.isNotBlank(employmentStatus)) {
            binds.put('employmentStatus', employmentStatus);
            baseQuery += ' AND Employment_Status__c = :employmentStatus';
        }

        Integer total = Database.countQueryWithBinds(
            'SELECT COUNT()' + baseQuery,
            binds,
            AccessLevel.USER_MODE
        );

        binds.put('limitSize', recordsPerPage);
        binds.put('offsetRows', offsetRows);

        String employeeQuery =
            'SELECT Id, Employee_ID__c, Name, Email__c,' +
            ' Department__r.Name, Job_Role__r.Name, Manager__r.Name,' +
            ' Joining_Date__c, Employment_Status__c' +
            baseQuery +
            ' ORDER BY Name ASC LIMIT :limitSize OFFSET :offsetRows';

        List<Employee__c> employeeRows =
            (List<Employee__c>) Database.queryWithBinds(
                employeeQuery,
                binds,
                AccessLevel.USER_MODE
            );

        EmployeeDirectoryResult result = new EmployeeDirectoryResult();
        result.employees = employeeRows;
        result.totalRecords = total;
        result.pageNumber = currentPage;
        result.pageSize = recordsPerPage;

        return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<FilterOption> getDepartments() {
        verifyCEOAccess();

        List<FilterOption> options = new List<FilterOption>();

        for (Department__c department : [
            SELECT Id, Name
            FROM Department__c
            WITH USER_MODE
            ORDER BY Name
        ]) {
            options.add(
                new FilterOption(department.Name, department.Id)
            );
        }

        return options;
    }
}