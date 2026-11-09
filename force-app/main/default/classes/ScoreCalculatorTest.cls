@IsTest
private class ScoreCalculatorTest {

    @IsTest
    static void heavyWorkloadGivesHighBurnout() {
        Decimal score = ScoreCalculator.burnoutScore(45, 4, 180, 1.5);
        System.assert(score >= 80, 'Burnout score was ' + score);
    }

    @IsTest
    static void relaxedEmployeeGivesLowBurnout() {
        Decimal score = ScoreCalculator.burnoutScore(0, 0, 10, 0);
        System.assert(score < 40, 'Burnout score was ' + score);
    }

    @IsTest
    static void topPerformerGetsHighPromotionScore() {
        Decimal score = ScoreCalculator.promotionScore(4.6, 100, 3, 100, 4.6, 6, 5);
        System.assert(score >= 90, 'Promotion score was ' + score);
    }

    @IsTest
    static void emptyValuesDoNotBreak() {
        Decimal score = ScoreCalculator.promotionScore(null, null, null, null, null, null, null);
        System.assertEquals(0, score);
    }

    @IsTest
    static void updaterSavesScoresOnEmployee() {
        Employee__c emp = new Employee__c(
            Email__c = 'test.employee@example.com',
            Joining_Date__c = Date.today().addDays(-400),
            Employment_Status__c = 'Active'
        );
        insert emp;

        Test.startTest();
        EmployeeScoreUpdater.updateScores(new Set<Id>{ emp.Id });
        Test.stopTest();

        Employee__c result = [SELECT Burnout_Score__c, Promotion_Score__c FROM Employee__c WHERE Id = :emp.Id];
        System.assertNotEquals(null, result.Burnout_Score__c);
        System.assertNotEquals(null, result.Promotion_Score__c);
    }
}