@IsTest
private class HrDashboardControllerTest {
 
    @TestSetup
    static void setup() {
        Department__c dep1 = new Department__c(Name = 'HR Test Dept A', Department_Code__c = 'HTA');
        Department__c dep2 = new Department__c(Name = 'HR Test Dept B', Department_Code__c = 'HTB');
        insert new List<Department__c>{ dep1, dep2 };
 
        Employee__c risk = new Employee__c(
            Name = 'Risk Rita', Email__c = 'rita@hr-test.com', Department__c = dep1.Id,
            Joining_Date__c = Date.today().addDays(-100), Employment_Status__c = 'Active',
            Annual_Leave_Balance__c = 20,
            Burnout_Score__c = 75, Attrition_Score__c = 72, Promotion_Score__c = 40);
        Employee__c star = new Employee__c(
            Name = 'Star Sam', Email__c = 'sam@hr-test.com', Department__c = dep1.Id,
            Joining_Date__c = Date.today().addDays(-100), Employment_Status__c = 'Active',
            Annual_Leave_Balance__c = 20,
            Burnout_Score__c = 20, Attrition_Score__c = 10, Promotion_Score__c = 92);
        Employee__c normal = new Employee__c(
            Name = 'Normal Nina', Email__c = 'nina@hr-test.com', Department__c = dep2.Id,
            Joining_Date__c = Date.today().addDays(-100), Employment_Status__c = 'Active',
            Annual_Leave_Balance__c = 20,
            Burnout_Score__c = 20, Attrition_Score__c = 20, Promotion_Score__c = 40);
        insert new List<Employee__c>{ risk, star, normal };
 
        Course__c course = new Course__c(Name = 'HR Test Course', Provider__c = 'Internal',
                                         Level__c = 'Beginner', Duration_Hours__c = 1);
        insert course;
 
        insert new Certification__c(Employee__c = risk.Id, Name = 'Test Cert',
            Issue_Date__c = Date.today().addDays(-300), Expiry_Date__c = Date.today().addDays(20));
        insert new Training__c(Employee__c = risk.Id, Course__c = course.Id, Status__c = 'Overdue',
            Assigned_Date__c = Date.today().addDays(-30), Due_Date__c = Date.today().addDays(-3),
            Assigned_By__c = 'HR');
        insert new Leave__c(Employee__c = risk.Id, Leave_Type__c = 'Annual',
            Start_Date__c = Date.today().addDays(5), End_Date__c = Date.today().addDays(6),
            Status__c = 'Pending');
        insert new Task(Subject = 'Burnout risk: Risk Rita', WhatId = risk.Id,
            Status = 'Not Started', Priority = 'High', ActivityDate = Date.today().addDays(-1));
    }
 
    @IsTest
    static void dashboardCountsAndWatchlist() {
        Test.startTest();
        HrDashboardController.HrDashboardData d = HrDashboardController.getHrDashboard(null);
        Test.stopTest();
 
        System.assertEquals(3, d.totalActive);
        System.assertEquals(1, d.burnoutHigh, 'Rita is High burnout');
        System.assertEquals(1, d.attritionHigh);
        System.assertEquals(1, d.promotionReady, 'Sam is 90+');
        System.assertEquals(2, d.watchlist.size(), 'Rita and Sam, not Nina');
        System.assertEquals('Risk Rita', d.watchlist[0].name, 'Highest risk first');
        System.assertEquals(1, d.openTaskCount);
        System.assertEquals(1, d.overdueTaskCount);
        System.assertEquals(1, d.certExpiringCount);
        System.assertEquals(1, d.trainingOverdueCount);
        System.assertEquals(1, d.pendingLeaveCount);
        System.assertEquals(1, d.tasks.size());
        System.assertEquals(1, d.certs.size());
        System.assertEquals(1, d.trainings.size());
        System.assertEquals(1, d.leaves.size());
        System.assertEquals(2, d.departments.size());
    }
 
    @IsTest
    static void departmentFilterNarrowsEverything() {
        Id depB = [SELECT Id FROM Department__c WHERE Department_Code__c = 'HTB'].Id;
        Test.startTest();
        HrDashboardController.HrDashboardData d = HrDashboardController.getHrDashboard(depB);
        Test.stopTest();
 
        System.assertEquals(1, d.totalActive);
        System.assertEquals(0, d.watchlist.size());
        System.assertEquals(0, d.openTaskCount);
        System.assertEquals(0, d.certExpiringCount);
    }
 
    @IsTest
    static void departmentsListLoads() {
        List<HrDashboardController.DeptOption> opts = HrDashboardController.getDepartments();
        System.assert(opts.size() >= 2);
    }
 
    @IsTest
    static void completeTaskClosesIt() {
        Task t = [SELECT Id FROM Task WHERE Subject LIKE 'Burnout risk%' LIMIT 1];
        Test.startTest();
        HrDashboardController.completeTask(t.Id);
        Test.stopTest();
        System.assertEquals(true, [SELECT IsClosed FROM Task WHERE Id = :t.Id].IsClosed);
 
        try {
            HrDashboardController.completeTask(t.Id);
            System.assert(false, 'Expected an exception');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
    }
 
    @IsTest
    static void scoreRefreshStartsAndReportsStatus() {
        Id jobId;
        Test.startTest();
        jobId = HrDashboardController.runScoreRefresh();
        Test.stopTest();
 
        System.assertNotEquals(null, jobId);
        HrDashboardController.JobInfo info = HrDashboardController.getJobStatus(jobId);
        System.assertEquals('Completed', info.status);
    }
}