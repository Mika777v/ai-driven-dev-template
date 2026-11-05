// 受け入れテスト（AI には見せない。作業が終わった後に backend/src/ に置いて流す）
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { startTestServer } from "./test-server";

describe("受け入れ: タクシー（API）", () => {
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
  const taxiRoute = { name: "駅↔客先", from: "C駅", to: "客先", transport: "taxi", oneWayFare: 1200 };

  it("タクシーのルートを登録でき、一覧に出る", async () => {
    const res = await send("POST", "/routes", taxiRoute);
    expect(res.status).toBe(201);
    const list = (await (await send("GET", "/routes")).json()) as { transport: string }[];
    expect(list.map((r) => r.transport)).toContain("taxi");
  });

  it("タクシーのルートで出勤を保存でき、記録にもタクシーが入る", async () => {
    const route = (await (await send("POST", "/routes", taxiRoute)).json()) as { id: string };
    const res = await send("PUT", "/daily-records/2026-11-02", { workStyle: { kind: "commute", routeId: route.id } });
    expect(res.status).toBe(200);
    const saved = (await res.json()) as { workStyle: { route: { transport: string } } };
    expect(saved.workStyle.route.transport).toBe("taxi");
  });

  it("タクシーの追加の移動を登録できる", async () => {
    await send("PUT", "/daily-records/2026-11-02", { workStyle: { kind: "remote" } });
    const res = await send("POST", "/daily-records/2026-11-02/extra-trips", {
      from: "A駅", to: "客先", transport: "taxi", oneWayFare: 1500, tripType: "oneWay",
    });
    expect(res.status).toBe(201);
  });

  it("一覧に無い値は今までどおり 400", async () => {
    expect((await send("POST", "/routes", { ...taxiRoute, transport: "plane" })).status).toBe(400);
  });
});
