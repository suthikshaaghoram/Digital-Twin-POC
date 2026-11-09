public class ScoreCalculator {

    public static Decimal burnoutScore(Decimal overtimeHours, Decimal weekendDays,
                                       Decimal daysSinceLeave, Decimal feedbackDrop) {

        Decimal overtimePart = percent(overtimeHours, 40);
        Decimal weekendPart  = percent(weekendDays, 6);
        Decimal noLeavePart  = percent(daysSinceLeave, 120);
        Decimal feedbackPart = percent(feedbackDrop, 1.5);

        Decimal score = (overtimePart * 0.35) + (weekendPart * 0.20)
                      + (noLeavePart * 0.25) + (feedbackPart * 0.20);

        return score.setScale(2);
    }

    public static Decimal promotionScore(Decimal reviewAvg, Decimal goalPercent, Decimal certCount,
                                         Decimal trainingPercent, Decimal feedbackAvg,
                                         Decimal experienceYears, Decimal requiredYears) {

        if (requiredYears == null || requiredYears <= 0) {
            requiredYears = 3;
        }

        Decimal reviewPart     = percent(reviewAvg, 5);
        Decimal goalPart       = percent(goalPercent, 100);
        Decimal certPart       = percent(certCount, 3);
        Decimal trainingPart   = percent(trainingPercent, 100);
        Decimal feedbackPart   = percent(feedbackAvg, 5);
        Decimal experiencePart = percent(experienceYears, requiredYears);

        Decimal score = (reviewPart * 0.30) + (goalPart * 0.20) + (certPart * 0.15)
                      + (trainingPart * 0.15) + (feedbackPart * 0.10) + (experiencePart * 0.10);

        return score.setScale(2);
    }

    private static Decimal percent(Decimal value, Decimal maxValue) {
        if (value == null || value <= 0) {
            return 0;
        }
        Decimal result = (value / maxValue) * 100;
        if (result > 100) {
            result = 100;
        }
        return result;
    }
}