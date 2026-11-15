# Generates out/T1-kien-truc-tong-quat.svg - the layered overall architecture diagram for lab 10, task 1.
# Hand-placed layout (no layout engine), so every box and arrow position below is deliberate.
import os
from xml.sax.saxutils import escape

W, H = 1400, 1010
FONT = "Segoe UI, Arial, Helvetica, sans-serif"
C = {
    "ink": "#1F2D3D", "muted": "#5D6D7E", "line": "#34495E",
    "layer": "#F4F6F8", "layer_b": "#AEB6BF",
    "client": "#E8F6F3", "client_b": "#148F77",
    "edge": "#FEF5E7", "edge_b": "#CA6F1E",
    "svc": "#EAF2FB", "svc_b": "#2E6DA4",
    "bus": "#FDEDEC", "bus_b": "#C0392B",
    "pg": "#F5B041", "es": "#58D68D", "mem": "#BFC9CA", "eu": "#BB8FCE",
    "infra": "#FBFCFC", "plat": "#EBEDEF", "plat_b": "#566573",
}
out = []


def rect(x, y, w, h, fill, stroke, rx=8, sw=1.4, dash=None):
    d = f' stroke-dasharray="{dash}"' if dash else ""
    out.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"{d}/>')


def text(x, y, s, size=11, weight="normal", fill=None, anchor="middle", style=""):
    fill = fill or C["ink"]
    out.append(f'<text x="{x}" y="{y}" font-size="{size}" font-weight="{weight}" fill="{fill}" text-anchor="{anchor}" {style}>{escape(s)}</text>')


def arrow(x1, y1, x2, y2, dash=None, both=False, color=None):
    color = color or C["line"]
    d = f' stroke-dasharray="{dash}"' if dash else ""
    start = ' marker-start="url(#ah)"' if both else ""
    out.append(f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{color}" stroke-width="1.6"{d} marker-end="url(#ah)"{start}/>')


def poly(points, dash=None):
    d = f' stroke-dasharray="{dash}"' if dash else ""
    pts = " ".join(f"{x},{y}" for x, y in points)
    out.append(f'<polyline points="{pts}" fill="none" stroke="{C["line"]}" stroke-width="1.6"{d} marker-end="url(#ah)"/>')


def label(x, y, s, anchor="middle"):
    w = len(s) * 5.6 + 10
    x0 = x - w / 2 if anchor == "middle" else x - 4
    out.append(f'<rect x="{x0}" y="{y - 11}" width="{w}" height="15" rx="3" fill="#FFFFFF" opacity="0.92"/>')
    text(x, y, s, 10, fill=C["muted"], anchor=anchor, style='font-style="italic"')


def chip(x, y, s, color):
    w = len(s) * 5.4 + 12
    out.append(f'<rect x="{x}" y="{y}" width="{w}" height="16" rx="8" fill="{color}" stroke="#00000022"/>')
    text(x + w / 2, y + 11.5, s, 9.5, "600")
    return w + 5


def layer(y, h, title):
    rect(20, y, W - 40, h, C["layer"], C["layer_b"], rx=10, sw=1, dash="5 4")
    text(32, y + 16, title, 11, "700", C["muted"], "start", 'letter-spacing="0.6"')


def box(x, y, w, h, fill, stroke, stereo, name, lines, chips=(), dash=None):
    rect(x, y, w, h, fill, stroke, dash=dash)
    cx = x + w / 2
    text(cx, y + 15, f"«{stereo}»", 9.5, fill=C["muted"], style='font-style="italic"')
    text(cx, y + 31, name, 13, "700")
    yy = y + 47
    for ln in lines:
        text(cx, yy, ln, 10.5)
        yy += 14
    if chips:
        total = sum(len(s) * 5.4 + 17 for s, _ in chips) - 5
        xx = cx - total / 2
        for s, col in chips:
            xx += chip(xx, y + h - 23, s, col)


# ---------- actor ----------
rect(560, 14, 280, 44, "#FFFFFF", C["ink"], rx=22)
text(700, 33, "Đại lý bảo hiểm (Sales Agent)", 13, "700")
text(700, 49, "Trình duyệt web: Chrome / Edge", 10.5, fill=C["muted"])

# ---------- client layer ----------
layer(84, 112, "TẦNG GIAO DIỆN  ·  Single Page Application chạy trong trình duyệt")
box(250, 108, 400, 78, C["client"], C["client_b"], "SPA · đang triển khai", "BlazorWasmClient  :5081",
    ["Blazor WebAssembly (.NET 8) · Blazorise + Bootstrap 5 · SignalR Client",
     "máy chủ tĩnh: Kestrel (WebAssembly DevServer)"])
box(750, 108, 400, 78, C["client"], C["client_b"], "SPA · có trong mã nguồn", "Web  :8080",
    ["Vue.js 2 · BootstrapVue · axios · vue-router · @aspnet/signalr",
     "máy chủ tĩnh + reverse proxy: Nginx (Web/Dockerfile)"], dash="6 3")
arrow(660, 58, 520, 106)
arrow(740, 58, 880, 106, dash="5 3")

# ---------- edge layer ----------
layer(226, 118, "TẦNG CỔNG VÀO  ·  bảo mật và định tuyến")
box(40, 252, 770, 80, C["edge"], C["edge_b"], "API Gateway", "AgentPortalApiGateway  :8099",
    ["Ocelot 23 trên Kestrel · xác thực JWT Bearer · kiểm tra claim userType=SALESMAN · cache 15 giây · CORS",
     "định tuyến theo tên service qua Ocelot.Provider.Eureka + Steeltoe Discovery"])
box(835, 252, 250, 80, C["edge"], C["edge_b"], "Microservice", "AuthService  :6060",
    ["ASP.NET Core Web API · phát hành JWT (HMAC-SHA256)", "danh sách đại lý lưu trong bộ nhớ (In-memory)"])
arrow(420, 186, 420, 250)
label(420, 215, "REST / JSON + JWT")
arrow(780, 186, 780, 250, dash="5 3")
arrow(600, 186, 900, 250)
label(790, 215, "POST /api/User (đăng nhập)")

# ---------- service layer ----------
rect(20, 374, W - 40, 196, C["layer"], C["layer_b"], rx=10, sw=1, dash="5 4")
text(1368, 390, "TẦNG DỊCH VỤ NGHIỆP VỤ", 11, "700", C["muted"], "end", 'letter-spacing="0.6"')
SW, GAP, SX, SY, SH = 154, 15, 40, 402, 148
svcs = [
    ("ProductService", ":5030", ["Danh mục sản phẩm", "EF Core 8 · MediatR", "Ensure.That"], [("In-memory", C["mem"]), ("Eureka", C["eu"])], None),
    ("PolicyService", ":5050", ["Báo giá và hợp đồng", "NHibernate 5 · Outbox", "RestEase · Polly · Serilog"], [("PostgreSQL", C["pg"]), ("Eureka", C["eu"])], None),
    ("PricingService", ":5040", ["Tính phí bảo hiểm", "Marten 7 · Serilog", "DynamicExpresso"], [("PostgreSQL", C["pg"]), ("Eureka", C["eu"])], None),
    ("PolicySearchService", ":5065", ["Tìm kiếm hợp đồng", "Elastic.Clients", ".Elasticsearch 8.9"], [("Elasticsearch", C["es"]), ("Eureka", C["eu"])], None),
    ("DashboardService", ":5035", ["Thống kê doanh số", "Elastic.Clients", ".Elasticsearch 8.9"], [("Elasticsearch", C["es"]), ("Eureka", C["eu"])], None),
    ("PaymentService", ":5070", ["Tài khoản hợp đồng", "Marten 7 · Dapper", "Hangfire (job nền)"], [("PostgreSQL", C["pg"])], None),
    ("ChatService", ":4099", ["Chat và thông báo", "SignalR Hub /agentsChat", "JWT Bearer"], [], None),
    ("DocumentService", "", ["Chứng chỉ PDF", "khung project,", "chưa triển khai JS Report"], [], "6 3"),
]
col = {}
for i, (name, port, lines, chips, dash) in enumerate(svcs):
    x = SX + i * (SW + GAP)
    col[name] = x + SW / 2
    box(x, SY, SW, SH, C["svc"], C["svc_b"], "Microservice", name, [port] + lines if port else lines, chips, dash)

# gateway -> routed services
for name in ("ProductService", "PolicyService", "PolicySearchService", "DashboardService"):
    arrow(col[name], 332, col[name], SY - 2)
label(col["ProductService"], 366, "/api/Products")
label(col["PolicyService"], 366, "/api/Offers · /api/Policies")
label(col["PolicySearchService"], 366, "/api/PolicySearch")
label(col["DashboardService"], 366, "/api/Dashboard")
# policy -> pricing (sync REST)
px = SX + 1 * (SW + GAP) + SW
arrow(px, SY + 62, px + GAP - 1, SY + 62)
# client -> chat (websocket)
poly([(640, 186), (640, 206), (1160, 206), (1160, 356), (col["ChatService"], 356), (col["ChatService"], SY - 2)])
label(1160, 290, "WebSocket (SignalR) + JWT")

# ---------- event bus ----------
BY = 612
rect(40, BY, W - 80, 46, C["bus"], C["bus_b"], rx=23)
text(700, BY + 19, "RabbitMQ 3  ·  Event Bus (AMQP 5672 · trang quản trị 15672)  ·  thư viện EasyNetQ", 13, "700")
text(700, BY + 36, "exchange kiểu topic «lab-dotnet-micro»  ·  sự kiện: PolicyCreated, PolicyTerminated  ·  mỗi service một hàng đợi riêng", 10.5, fill=C["muted"])
arrow(col["PolicyService"], SY + SH, col["PolicyService"], BY - 2)
label(col["PolicyService"], 586, "phát sự kiện (Outbox)")
for name in ("PolicySearchService", "DashboardService", "PaymentService", "ChatService"):
    arrow(col[name], BY, col[name], SY + SH + 2)
label((col["DashboardService"] + col["PaymentService"]) / 2, 586, "nhận sự kiện (đăng ký hàng đợi)")

# ---------- shared infrastructure ----------
layer(676, 126, "TẦNG HẠ TẦNG DÙNG CHUNG  ·  nhãn màu trên mỗi service cho biết service đó dùng thành phần nào")
IW, IX, IY, IH = 318, 40, 702, 88
infra = [
    ("Service Registry", "Eureka Server  :8761", ["Spring Boot 2.4 · Spring Cloud Netflix", "Java 8 (Temurin) · Tomcat nhúng · Gradle"], C["eu"]),
    ("RDBMS / Document DB", "PostgreSQL 16  :5432", ["lab_netmicro_policy · lab_netmicro_pricing", "lab_netmicro_payments · lab_netmicro_jobs"], C["pg"]),
    ("Search Engine", "Elasticsearch 8.9.2  :9200", ["chỉ mục lab_policies (tìm kiếm)", "chỉ mục thống kê doanh số"], C["es"]),
    ("Lưu trong tiến trình", "Bộ nhớ trong (In-memory)", ["EF Core InMemory: danh mục sản phẩm", "danh sách đại lý của AuthService"], C["mem"]),
]
for i, (stereo, name, lines, color) in enumerate(infra):
    x = IX + i * (IW + 16)
    rect(x, IY, IW, IH, C["infra"], C["layer_b"])
    rect(x, IY, 10, IH, color, color, rx=4)
    cx = x + IW / 2 + 5
    text(cx, IY + 16, f"«{stereo}»", 9.5, fill=C["muted"], style='font-style="italic"')
    text(cx, IY + 34, name, 13, "700")
    text(cx, IY + 52, lines[0], 10.5)
    text(cx, IY + 67, lines[1], 10.5)

# ---------- platform ----------
PY = 820
rect(20, PY, W - 40, 84, C["plat"], C["plat_b"], rx=10)
text(700, PY + 22, "NỀN TẢNG TRIỂN KHAI:  Docker Engine (Docker Desktop · WSL 2 trên Windows 11)  +  Docker Compose", 13, "700")
text(700, PY + 42, "14 container Linux trên một mạng bridge: 9 microservice + web từ image insurance-lab9 (mcr.microsoft.com/dotnet/sdk:8.0) · eureka-server · postgres · elasticsearch · rabbit", 10.5)
text(700, PY + 59, "Web server: Kestrel (mọi service ASP.NET Core 8 Web API, Gateway, Blazor DevServer) · Nginx (Web Vue) · Tomcat nhúng (Eureka) · mỗi service dùng MediatR (CQRS) + Swagger/OpenAPI", 10.5)
text(700, PY + 76, "Cấu hình theo môi trường: appsettings.json / appsettings.docker.json / ocelot.json · healthcheck + depends_on trong scripts/lab9.docker.yml", 10.5)

rect(20, 916, W - 40, 40, "#FFFFFF", C["layer_b"], rx=10, sw=1)
text(700, 933, "NỀN TẢNG PHÁT TRIỂN VÀ KIỂM THỬ:  .NET SDK 8.0.425 · C# 12 · Visual Studio / VS Code · Node.js 10 + Vue CLI (Web) · Git · GitHub · GitHub Actions (CI)", 10.5, "600")
text(700, 948, "xUnit · Testcontainers (PostgreSQL, Elasticsearch) · Swagger UI · PowerShell (scripts/verify-lab9.ps1)", 10.5)

# ---------- legend ----------
ly = 984
text(30, ly, "Chú giải:", 10.5, "700", anchor="start")
out.append(f'<line x1="90" y1="{ly - 4}" x2="130" y2="{ly - 4}" stroke="{C["line"]}" stroke-width="1.6" marker-end="url(#ah)"/>')
text(138, ly, "lời gọi / luồng dữ liệu", 10.5, anchor="start")
out.append(f'<rect x="275" y="{ly - 12}" width="34" height="14" rx="3" fill="#FFFFFF" stroke="{C["svc_b"]}" stroke-dasharray="6 3"/>')
text(316, ly, "có trong mã nguồn nhưng không nằm trong bản triển khai Docker của Bài 9", 10.5, anchor="start")
x = 700
for s, col_ in (("PostgreSQL", C["pg"]), ("Elasticsearch", C["es"]), ("In-memory", C["mem"]), ("Eureka", C["eu"])):
    x += chip(x, ly - 12, s, col_)
text(x + 4, ly, "= service lưu dữ liệu ở đó / có đăng ký với Eureka", 10.5, anchor="start")

svg = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}" font-family="{FONT}">
<defs><marker id="ah" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse"><path d="M0,0 L10,5 L0,10 z" fill="{C["line"]}"/></marker></defs>
<rect width="{W}" height="{H}" fill="#FFFFFF"/>
''' + "\n".join(out) + "\n</svg>\n"
here = os.path.dirname(os.path.abspath(__file__))
os.makedirs(os.path.join(here, "out"), exist_ok=True)
open(os.path.join(here, "out", "T1-kien-truc-tong-quat.svg"), "w", encoding="utf-8", newline="\n").write(svg)
print("written", len(svg))
