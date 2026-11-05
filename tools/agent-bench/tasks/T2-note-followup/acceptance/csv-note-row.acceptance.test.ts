// 受け入れテスト（AI には見せない。作業が終わった後に shared/src/ に置いて流す）
import { describe, expect, it } from "vitest";
import * as csv from "./csv";

type Rec = Parameters<typeof csv.monthCsvRows>[0][number];

const route = { name: "自宅↔本社", from: "A駅", to: "B駅", transport: "train", oneWayFare: 220 } as const;
const header = csv.CSV_HEADER as readonly string[];
const col = (name: string) => header.indexOf(name);

describe("受け入れ（続き）: 移動の無い日のメモの行", () => {
  it("在宅で移動の無い日にメモがあると、種別「メモ」の1行が出る", () => {
    const record = { date: "2026-11-05", workStyle: { kind: "remote" }, extraTrips: [], note: "健康診断" } as unknown as Rec;
    const rows = csv.monthCsvRows([record]);
    expect(rows).toHaveLength(1);
    const row = rows[0] as readonly string[];
    expect(row).toHaveLength(header.length);
    expect(row[col("日付")]).toBe("2026-11-05");
    expect(row[col("曜日")]).toBe("木");
    expect(row[col("勤務区分")]).toBe("在宅");
    expect(row[col("種別")]).toBe("メモ");
    for (const name of ["出発地", "到着地", "交通手段", "片道/往復", "片道運賃", "金額", "ルート名", "目的"]) {
      expect(row[col(name)], name).toBe("");
    }
    expect(row[header.length - 1]).toBe("健康診断");
  });

  it("休日で移動の無い日でも、メモがあれば1行出る（祝日名も入る）", () => {
    const record = { date: "2026-11-03", workStyle: { kind: "holiday" }, extraTrips: [], note: "文化の日" } as unknown as Rec;
    const rows = csv.monthCsvRows([record]);
    expect(rows).toHaveLength(1);
    expect(rows[0]?.[col("祝日")]).toBe("文化の日");
    expect(rows[0]?.[col("勤務区分")]).toBe("休日");
    expect(rows[0]?.[col("種別")]).toBe("メモ");
  });

  it("移動のある日は、今までどおり（メモの行は足さない）", () => {
    const record = { date: "2026-11-04", workStyle: { kind: "commute", routeId: "r1", route }, extraTrips: [], note: "客先へ" } as unknown as Rec;
    const rows = csv.monthCsvRows([record]);
    expect(rows).toHaveLength(1);
    expect(rows[0]?.[col("種別")]).toBe("通常");
    expect(rows[0]?.[header.length - 1]).toBe("客先へ");
  });

  it("メモも移動も無い日は、今までどおり行を作らない", () => {
    const record = { date: "2026-11-05", workStyle: { kind: "remote" }, extraTrips: [] } as unknown as Rec;
    expect(csv.monthCsvRows([record])).toEqual([]);
  });

  it("金額の列の和は、メモの行があっても月の合計と変わらない（メモの行は金額が空）", () => {
    const records = [
      { date: "2026-11-04", workStyle: { kind: "commute", routeId: "r1", route }, extraTrips: [] },
      { date: "2026-11-05", workStyle: { kind: "remote" }, extraTrips: [], note: "在宅" },
    ] as unknown as Rec[];
    const sum = csv.monthCsvRows(records).reduce((acc, row) => acc + Number(row[col("金額")] || 0), 0);
    expect(sum).toBe(440);
  });
});
