// 受け入れテスト（AI には見せない。作業が終わった後に shared/src/ に置いて流す）
import { describe, expect, it } from "vitest";
import { TRANSPORTS } from "./route";
import * as csv from "./csv";

type Rec = Parameters<typeof csv.monthCsvRows>[0][number];

describe("受け入れ: タクシー（型と CSV）", () => {
  it("交通手段の一覧は 電車・バス・タクシー・その他 の順", () => {
    expect([...TRANSPORTS]).toEqual(["train", "bus", "taxi", "other"]);
  });
  it("CSV の交通手段に「タクシー」と出る", () => {
    const route = { name: "駅↔客先", from: "C駅", to: "客先", transport: "taxi", oneWayFare: 1200 };
    const rows = csv.monthCsvRows([{ date: "2026-11-04", workStyle: { kind: "commute", routeId: "r2", route }, extraTrips: [] } as unknown as Rec]);
    expect(rows[0]?.[7]).toBe("タクシー");
  });
});
