// 受け入れテスト（AI には見せない）: CSV の中身は変わらないこと
import { describe, expect, it } from "vitest";
import { CSV_HEADER, monthCsvRows } from "./csv";

describe("受け入れ: CSV の中身はそのまま", () => {
  it("見出しは今までの13列", () => {
    expect(CSV_HEADER).toEqual(["日付", "曜日", "祝日", "勤務区分", "種別", "出発地", "到着地", "交通手段", "片道/往復", "片道運賃", "金額", "ルート名", "目的"]);
  });
  it("出勤日の行は今までどおり", () => {
    const route = { name: "自宅↔本社", from: "A駅", to: "B駅", transport: "train", oneWayFare: 220 } as const;
    const rows = monthCsvRows([{ date: "2026-11-04", workStyle: { kind: "commute", routeId: "r1", route }, extraTrips: [] }]);
    expect(rows).toEqual([["2026-11-04", "水", "", "出勤", "通常", "A駅", "B駅", "電車", "往復", "220", "440", "自宅↔本社", ""]]);
  });
});
