/**
 * 고객 수요 예측(FCST)으로 장비별 생산능력(CAPA)과 가동률을 계산한다.
 *
 *   1대 하루 CAPA = 하루 가동 시간(초) / 1개당 테스트 시간(초)
 *   기간 CAPA     = 1대 하루 CAPA × 장비 대수 × 기간 일수
 *   가동률(%)     = 수요 / 기간 CAPA × 100
 *
 * 기간 라벨은 월(2026-03)과 주(2026-W05)가 섞여 들어올 수 있어
 * 라벨마다 단위를 판별하고, 월은 실제 일수(윤년 포함)를 쓴다.
 */
public with sharing class CapacityForecast {

    public class ForecastException extends Exception {}

    public class Equipment {
        public String name;
        public Integer unitCount;
        public Decimal uptimeHoursPerDay;

        public Equipment(String name, Integer unitCount, Decimal uptimeHoursPerDay) {
            this.name = name;
            this.unitCount = unitCount;
            this.uptimeHoursPerDay = uptimeHoursPerDay;
        }
    }

    public class DemandRow {
        public String equipmentName;
        public Decimal testTimeSeconds;
        public String period;
        public Decimal demand;

        public DemandRow(String equipmentName, Decimal testTimeSeconds, String period, Decimal demand) {
            this.equipmentName = equipmentName;
            this.testTimeSeconds = testTimeSeconds;
            this.period = period;
            this.demand = demand;
        }
    }

    public class PeriodResult {
        public String equipmentName;
        public String period;
        public Decimal demand;
        public Decimal capa;
        public Decimal utilization;
    }

    private static final Pattern MONTH = Pattern.compile('^(\\d{4})-(\\d{2})$');
    private static final Pattern WEEK = Pattern.compile('^(\\d{4})-W(\\d{2})$');

    /**
     * 수요 행 전체를 계산한다. 장비 마스터는 이름으로 한 번만 묶어 두고 재사용한다.
     * 장비명은 대소문자 · 공백 차이를 무시하고 맞춘다.
     */
    public static List<PeriodResult> calculate(List<Equipment> equipments, List<DemandRow> rows) {
        Map<String, Equipment> equipmentByName = new Map<String, Equipment>();
        for (Equipment eq : equipments) {
            equipmentByName.put(normalizeName(eq.name), eq);
        }

        List<PeriodResult> results = new List<PeriodResult>();
        for (DemandRow row : rows) {
            Equipment eq = equipmentByName.get(normalizeName(row.equipmentName));
            if (eq == null) {
                throw new ForecastException('장비 마스터에 없는 장비: ' + row.equipmentName);
            }
            PeriodResult result = new PeriodResult();
            result.equipmentName = eq.name;
            result.period = row.period;
            result.demand = row.demand;
            result.capa = periodCapa(eq, row.testTimeSeconds, row.period);
            result.utilization = result.capa == 0 ? 0 : (row.demand / result.capa * 100).setScale(1);
            results.add(result);
        }
        return results;
    }

    public static Decimal periodCapa(Equipment eq, Decimal testTimeSeconds, String period) {
        if (testTimeSeconds == null || testTimeSeconds <= 0) {
            return 0;
        }
        Decimal dailyPerUnit = (eq.uptimeHoursPerDay * 3600 / testTimeSeconds).round(System.RoundingMode.FLOOR);
        return dailyPerUnit * eq.unitCount * daysIn(period);
    }

    /**
     * @return 월이면 실제 일수, 주면 7
     */
    public static Integer daysIn(String period) {
        Matcher month = MONTH.matcher(period == null ? '' : period.trim());
        if (month.matches()) {
            return Date.daysInMonth(Integer.valueOf(month.group(1)), Integer.valueOf(month.group(2)));
        }
        if (WEEK.matcher(period == null ? '' : period.trim()).matches()) {
            return 7;
        }
        throw new ForecastException('알 수 없는 기간 형식: ' + period);
    }

    /**
     * 전기 비교용 직전 기간. 2026-01 → 2025-12, 2026-W01 → 2025-W52
     */
    public static String previousPeriod(String period) {
        Matcher month = MONTH.matcher(period);
        if (month.matches()) {
            Date first = Date.newInstance(Integer.valueOf(month.group(1)), Integer.valueOf(month.group(2)), 1).addMonths(-1);
            return first.year() + '-' + String.valueOf(first.month()).leftPad(2, '0');
        }
        Matcher week = WEEK.matcher(period);
        if (week.matches()) {
            Integer year = Integer.valueOf(week.group(1));
            Integer weekNo = Integer.valueOf(week.group(2));
            return weekNo > 1
                ? year + '-W' + String.valueOf(weekNo - 1).leftPad(2, '0')
                : (year - 1) + '-W52';
        }
        throw new ForecastException('알 수 없는 기간 형식: ' + period);
    }

    private static String normalizeName(String name) {
        return name == null ? '' : name.replaceAll('\\s+', '').toUpperCase();
    }
}
