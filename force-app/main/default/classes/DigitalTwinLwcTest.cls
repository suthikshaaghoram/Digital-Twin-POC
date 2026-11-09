@IsTest
private class DigitalTwinLwcTest {

    @TestSetup
    static void setup() {

        Department__c dep = new Department__c(
            Name = 'Test Dept',
            Department_Code__c = 'TST'
        );
        insert dep;

        Employee__c boss = new Employee__c(
            Name = 'Test Boss',
            Name__c = 'Test Boss',
            Email__c = 'boss@lwc-test.com',
            Department__c = dep.Id,
            Joining_Date__c = Date.today().addDays(-500),
            Employment_Status__c = 'Active',
            Annual_Leave_Balance__c = 20,
            User__c = UserInfo.getUserId()
        );
        insert boss;

        Employee__c emp = new Employee__c(
            Name = 'Test Report',
            Name__c = 'Test Report',
            Email__c = 'report@lwc-test.com',
            Department__c = dep.Id,
            Manager__c = boss.Id,
            Joining_Date__c = Date.today().addDays(-400),
            Employment_Status__c = 'Active',
            Annual_Leave_Balance__c = 20,
            Burnout_Score__c = 55,
            Promotion_Score__c = 75,
            Attrition_Score__c = 45
        );
        insert emp;

        insert new Goal__c(
            Employee__c = emp.Id,
            Goal_Title__c = 'Goal 1',
            Target_Value__c = 100,
            Actual_Value__c = 50,
            Deadline__c = Date.today().addDays(-5),
            Status__c = 'In Progress'
        );
    }

    @IsTest
    static void twinPayloadLoads() {

        Employee__c emp = [
            SELECT Id
            FROM Employee__c
            WHERE Name = 'Test Report'
            LIMIT 1
        ];

        Test.startTest();

        DigitalTwinController.TwinData d =
            DigitalTwinController.getEmployeeTwin(emp.Id);

        Test.stopTest();

        System.assertEquals('Test Report', d.employee.Name);
        System.assertEquals(1, d.goals.size());
    }

    @IsTest
    static void dashboardAggregates() {

        Test.startTest();

        DashboardController.DashboardData d =
            DashboardController.getDashboard();

        Test.stopTest();

        System.assert(
            d.totalActive >= 2,
            'Active employees: ' + d.totalActive
        );

        System.assert(
            d.promotionReady >= 1,
            'Promotion ready: ' + d.promotionReady
        );

        System.assert(
            !d.departments.isEmpty(),
            'Department statistics should not be empty'
        );
    }

    @IsTest
    static void managerSeesTeam() {

        Test.startTest();

        List<Employee__c> team =
            DashboardController.getMyTeam();

        Test.stopTest();

        System.assertEquals(1, team.size());
        System.assertEquals('Test Report', team[0].Name);
    }
}