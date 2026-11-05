// 受け入れテスト（AI には見せない。作業が終わった後に shared/src/ に置いて流す）
import { describe, expect, it } from "vitest";
import { csvFileName } from "./csv";

describe("受け入れ: CSV のファイル名", () => {
  it("交通費_YYYY-MM.csv になる", () => {
    expect(csvFileName("2026-11")).toBe("交通費_2026-11.csv");
    expect(csvFileName("2027-01")).toBe("交通費_2027-01.csv");
  });
});
