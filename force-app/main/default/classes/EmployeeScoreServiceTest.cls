@IsTest
private class EmployeeScoreServiceTest {

    private static Employee__c makeEmployee(String name) {
      Employee__c e = new Employee__c(
    Name__c = name,
    Email__c = name.replaceAll('\\s', '').toLowerCase() + '@example.com',
    Joining_Date__c = Date.today().addDays(-400),
    Employment_Status__c = 'Active',
    Annual_Leave_Balance__c = 12
);
        insert e;
        return e;
    }

    
private static void addAttendance(Id empId, Integer days, Integer hoursWorked) {
    List<Attendance__c> rows = new List<Attendance__c>();

    for (Integer i = 1; i <= days; i++) {
        Date d = Date.today().addDays(-i);

        String dateKey =
            String.valueOf(d.year()) +
            (d.month() < 10 ? '0' : '') + String.valueOf(d.month()) +
            (d.day() < 10 ? '0' : '') + String.valueOf(d.day());

        String attendanceKey = String.valueOf(empId).right(7) + '_' + dateKey;

        rows.add(new Attendance__c(
            Employee__c = empId,
            Date__c = d,
            Status__c = 'Present',
            Key__c = attendanceKey,
            Login_Time__c = Datetime.newInstance(
                d, Time.newInstance(9, 0, 0, 0)
            ),
            Logout_Time__c = Datetime.newInstance(
                d, Time.newInstance(9 + hoursWorked, 0, 0, 0)
            )
        ));
    }

    insert rows;
}


    @IsTest
    static void stressedEmployeeGetsHighBurnout() {
        Employee__c emp = makeEmployee('Stressed Sam');
        addAttendance(emp.Id, 30, 11);          // 3 overtime hours every day, including weekends

        Test.startTest();
        EmployeeScoreService.calculate(new Set<Id>{ emp.Id });
        Test.stopTest();

        Employee__c after = [SELECT Burnout_Score__c, Total_Overtime_30d__c, Last_Score_Date__c
                             FROM Employee__c WHERE Id = :emp.Id];
        System.assert(after.Burnout_Score__c >= 85, 'Burnout was ' + after.Burnout_Score__c);
        System.assert(after.Total_Overtime_30d__c > 0);
        System.assertNotEquals(null, after.Last_Score_Date__c);
    }

    @IsTest
    static void strongEmployeeGetsHighPromotionScore() {
        Employee__c emp = makeEmployee('Strong Sara');
        insert new Performance_Review__c(
            Employee__c = emp.Id, Review_Quarter__c = 'Q1', Review_Year__c = Date.today().year(),
            Manager_Rating__c = 4.7, Technical_Rating__c = 4.7,
            Communication_Rating__c = 4.7, Leadership_Rating__c = 4.7, Status__c = 'Finalised');
        insert new Goal__c(Employee__c = emp.Id, Goal_Title__c = 'Deliver project',
            Target_Value__c = 100, Actual_Value__c = 100,
            Deadline__c = Date.today().addDays(-10), Status__c = 'Achieved');
        List<Certification__c> certs = new List<Certification__c>();
        for (Integer i = 1; i <= 3; i++) {
            certs.add(new Certification__c(Employee__c = emp.Id,Name = 'Salesforce Administrator' + i,
                Issue_Date__c = Date.today().addDays(-200), Expiry_Date__c = Date.today().addDays(300)));
        }
        insert certs;

        Test.startTest();
        EmployeeScoreService.calculate(new Set<Id>{ emp.Id });
        Test.stopTest();

        Employee__c after = [SELECT Promotion_Score__c FROM Employee__c WHERE Id = :emp.Id];
        System.assert(after.Promotion_Score__c >= 90, 'Promotion was ' + after.Promotion_Score__c);
    }

    @IsTest
    static void batchSchedulerAndFlowActionRun() {
        Employee__c emp = makeEmployee('Batch Bella');

        Test.startTest();
        Database.executeBatch(new EmployeeScoreService(), 50);
        Test.stopTest();
        System.assertNotEquals(null,
            [SELECT Last_Score_Date__c FROM Employee__c WHERE Id = :emp.Id].Last_Score_Date__c);

        EmployeeScoreService.recalculate(new List<Id>{ emp.Id });
        String jobId = System.schedule('Test nightly score refresh', '0 0 1 * * ?',
                                       new EmployeeScoreService());
        System.assertEquals(1, [SELECT COUNT() FROM CronTrigger WHERE Id = :jobId]);
    }
}