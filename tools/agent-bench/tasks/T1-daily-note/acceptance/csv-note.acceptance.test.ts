// 受け入れテスト（AI には見せない。作業が終わった後に shared/src/ に置いて流す）
import { describe, expect, it } from "vitest";
import * as csv from "./csv";

type Rec = Parameters<typeof csv.monthCsvRows>[0][number];

const route = { name: "自宅↔本社", from: "A駅", to: "B駅", transport: "train", oneWayFare: 220 } as const;

describe("受け入れ: CSV のメモ", () => {
  it("見出しの最後の列が「メモ」", () => {
    expect(csv.CSV_HEADER[csv.CSV_HEADER.length - 1]).toBe("メモ");
  });

  it("その日の行のすべてに、同じメモが入る", () => {
    const record = {
      date: "2026-11-02",
      workStyle: { kind: "commute", routeId: "r1", route },
      extraTrips: [{ id: "t1", from: "B駅", to: "C駅", transport: "bus", oneWayFare: 160, tripType: "roundTrip" }],
      note: "客先へ",
    } as unknown as Rec;
    const rows = csv.monthCsvRows([record]);
    expect(rows).toHaveLength(2);
    for (const row of rows) expect(row[row.length - 1]).toBe("客先へ");
  });

  it("メモの無い日は空", () => {
    const record = { date: "2026-11-02", workStyle: { kind: "commute", routeId: "r1", route }, extraTrips: [] } as unknown as Rec;
    const rows = csv.monthCsvRows([record]);
    // メモの列があること（列の数が見出しと同じで、見出しの最後が「メモ」）と、その列が空であること
    expect(csv.CSV_HEADER[csv.CSV_HEADER.length - 1]).toBe("メモ");
    expect(rows[0]).toHaveLength(csv.CSV_HEADER.length);
    expect(rows[0]?.[rows[0].length - 1]).toBe("");
  });

  it("カンマや改行を含むメモも、CSV の文字列で壊れない", () => {
    const record = {
      date: "2026-11-02",
      workStyle: { kind: "commute", routeId: "r1", route },
      extraTrips: [],
      note: "A,B\n次",
    } as unknown as Rec;
    expect(csv.monthCsv([record])).toContain('"A,B\n次"');
  });
});
