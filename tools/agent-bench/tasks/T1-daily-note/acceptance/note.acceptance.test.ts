// 受け入れテスト（AI には見せない。作業が終わった後に backend/src/daily-records/ に置いて流す）
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { startTestServer } from "../test-server";

describe("受け入れ: 日次記録のメモ", () => {
  let server: ReturnType<typeof startTestServer>;
  beforeEach(() => {
    server = startTestServer();
  });
  afterEach(() => {
    server.close();
  });

  function send(method: string, path: string, body?: unknown) {
    return fetch(`${server.baseUrl}/api${path}`, {
      method,
      headers: { "Content-Type": "application/json" },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
  }
  async function month(m: string): Promise<Record<string, unknown>[]> {
    return (await (await send("GET", `/daily-records?month=${m}`)).json()) as Record<string, unknown>[];
  }

  it("記録にメモを付けると、その日の記録が返り、月の取得でも返る", async () => {
    await send("PUT", "/daily-records/2026-11-02", { workStyle: { kind: "remote" } });
    const res = await send("PUT", "/daily-records/2026-11-02/note", { note: "健康診断で直帰" });
    expect(res.status).toBe(200);
    const saved = (await res.json()) as Record<string, unknown>;
    expect(saved.date).toBe("2026-11-02");
    expect(saved.note).toBe("健康診断で直帰");
    const list = await month("2026-11");
    expect(list.find((r) => r.date === "2026-11-02")?.note).toBe("健康診断で直帰");
  });

  it("前後の空白は除き、メモを直せる", async () => {
    await send("PUT", "/daily-records/2026-11-02", { workStyle: { kind: "remote" } });
    await send("PUT", "/daily-records/2026-11-02/note", { note: "最初" });
    const res = await send("PUT", "/daily-records/2026-11-02/note", { note: "  直した  " });
    expect(((await res.json()) as Record<string, unknown>).note).toBe("直した");
  });

  it("空を送るとメモが消え、プロパティごと無くなる", async () => {
    await send("PUT", "/daily-records/2026-11-02", { workStyle: { kind: "remote" } });
    await send("PUT", "/daily-records/2026-11-02/note", { note: "消す" });
    const res = await send("PUT", "/daily-records/2026-11-02/note", { note: "   " });
    expect(res.status).toBe(200);
    expect("note" in ((await res.json()) as Record<string, unknown>)).toBe(false);
    const list = await month("2026-11");
    expect("note" in (list.find((r) => r.date === "2026-11-02") ?? {})).toBe(false);
  });

  it("メモの無い日は note のプロパティが無い", async () => {
    await send("PUT", "/daily-records/2026-11-03", { workStyle: { kind: "remote" } });
    const list = await month("2026-11");
    expect("note" in (list.find((r) => r.date === "2026-11-03") ?? {})).toBe(false);
  });

  it("200 文字までは保存でき、201 文字は 400（field は note）", async () => {
    await send("PUT", "/daily-records/2026-11-02", { workStyle: { kind: "remote" } });
    expect((await send("PUT", "/daily-records/2026-11-02/note", { note: "あ".repeat(200) })).status).toBe(200);
    const res = await send("PUT", "/daily-records/2026-11-02/note", { note: "あ".repeat(201) });
    expect(res.status).toBe(400);
    const body = (await res.json()) as { fieldErrors?: { field: string }[] };
    expect(body.fieldErrors?.some((e) => e.field === "note")).toBe(true);
  });

  it("文字列でないと 400", async () => {
    await send("PUT", "/daily-records/2026-11-02", { workStyle: { kind: "remote" } });
    expect((await send("PUT", "/daily-records/2026-11-02/note", { note: 123 })).status).toBe(400);
    expect((await send("PUT", "/daily-records/2026-11-02/note", {})).status).toBe(400);
  });

  it("記録の無い日に付けようとすると 404", async () => {
    expect((await send("PUT", "/daily-records/2026-11-05/note", { note: "x" })).status).toBe(404);
  });

  it("勤務区分を保存し直しても、メモは残る", async () => {
    await send("PUT", "/daily-records/2026-11-02", { workStyle: { kind: "remote" } });
    await send("PUT", "/daily-records/2026-11-02/note", { note: "残す" });
    const res = await send("PUT", "/daily-records/2026-11-02", { workStyle: { kind: "holiday" } });
    expect(((await res.json()) as Record<string, unknown>).note).toBe("残す");
  });

  it("一括設定で上書きしても、メモは残る", async () => {
    await send("PUT", "/daily-records/2026-11-02", { workStyle: { kind: "remote" } });
    await send("PUT", "/daily-records/2026-11-02/note", { note: "残す" });
    const res = await send("POST", "/daily-records/bulk", { days: [{ date: "2026-11-02", workStyle: { kind: "holiday" } }] });
    expect(res.status).toBe(200);
    const list = await month("2026-11");
    expect(list.find((r) => r.date === "2026-11-02")?.note).toBe("残す");
  });
});
