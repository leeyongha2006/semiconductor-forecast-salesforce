@IsTest
private class CapacityForecast_Test {

    private static List<CapacityForecast.Equipment> equipments() {
        // 하루 20시간 가동하는 장비 3대
        return new List<CapacityForecast.Equipment>{ new CapacityForecast.Equipment('Tester A', 3, 20) };
    }

    @IsTest
    static void calculatesMonthlyCapaWithActualDays() {
        // 1개 60초 → 1대 하루 1,200개 → 3대 × 28일(2026-02) = 100,800
        List<CapacityForecast.PeriodResult> results = CapacityForecast.calculate(
            equipments(),
            new List<CapacityForecast.DemandRow>{ new CapacityForecast.DemandRow('Tester A', 60, '2026-02', 50400) }
        );
        Assert.areEqual(100800, results[0].capa);
        Assert.areEqual(50.0, results[0].utilization);
    }

    @IsTest
    static void calculatesWeeklyCapa() {
        List<CapacityForecast.PeriodResult> results = CapacityForecast.calculate(
            equipments(),
            new List<CapacityForecast.DemandRow>{ new CapacityForecast.DemandRow('Tester A', 60, '2026-W05', 25200) }
        );
        Assert.areEqual(25200, results[0].capa);
        Assert.areEqual(100.0, results[0].utilization);
    }

    @IsTest
    static void matchesEquipmentNamesLoosely() {
        List<CapacityForecast.PeriodResult> results = CapacityForecast.calculate(
            equipments(),
            new List<CapacityForecast.DemandRow>{ new CapacityForecast.DemandRow('  tester  a', 60, '2026-03', 0) }
        );
        Assert.areEqual('Tester A', results[0].equipmentName);
    }

    @IsTest
    static void handlesLeapYearAndZeroTestTime() {
        Assert.areEqual(29, CapacityForecast.daysIn('2028-02'));
        CapacityForecast.Equipment eq = equipments()[0];
        Assert.areEqual(0, CapacityForecast.periodCapa(eq, 0, '2026-01'));
    }

    @IsTest
    static void findsPreviousPeriodAcrossYears() {
        Assert.areEqual('2025-12', CapacityForecast.previousPeriod('2026-01'));
        Assert.areEqual('2025-W52', CapacityForecast.previousPeriod('2026-W01'));
        Assert.areEqual('2026-W09', CapacityForecast.previousPeriod('2026-W10'));
    }

    @IsTest
    static void rejectsUnknownEquipmentAndPeriod() {
        try {
            CapacityForecast.calculate(equipments(), new List<CapacityForecast.DemandRow>{
                new CapacityForecast.DemandRow('Tester Z', 60, '2026-01', 1)
            });
            Assert.fail('예외가 나야 한다');
        } catch (CapacityForecast.ForecastException e) {
            Assert.isTrue(e.getMessage().contains('Tester Z'));
        }
        try {
            CapacityForecast.daysIn('26년 1월');
            Assert.fail('예외가 나야 한다');
        } catch (CapacityForecast.ForecastException e) {
            Assert.isTrue(e.getMessage().contains('기간 형식'));
        }
    }

    @IsTest
    static void handlesThousandsOfRows() {
        List<CapacityForecast.DemandRow> rows = new List<CapacityForecast.DemandRow>();
        for (Integer i = 0; i < 3000; i++) {
            rows.add(new CapacityForecast.DemandRow('Tester A', 60, '2026-W' + String.valueOf(Math.mod(i, 52) + 1).leftPad(2, '0'), 1000));
        }
        Test.startTest();
        List<CapacityForecast.PeriodResult> results = CapacityForecast.calculate(equipments(), rows);
        Test.stopTest();
        Assert.areEqual(3000, results.size());
    }
}
