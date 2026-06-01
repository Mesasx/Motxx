/* ============================================================
   Motex Campus · nucleo de cliente compartido
   Crea el cliente de Supabase y expone utilidades comunes en
   window.MC (sesion, perfil, guardas de acceso, formato, etc.).
   Requiere que antes se haya cargado el SDK de Supabase y config.js.
   ============================================================ */
(function () {
  "use strict";

  var cfg = window.MOTEX_CAMPUS_CONFIG || {};
  var configured =
    cfg.SUPABASE_URL &&
    cfg.SUPABASE_ANON_KEY &&
    cfg.SUPABASE_URL.indexOf("YOUR-PROJECT") === -1 &&
    cfg.SUPABASE_ANON_KEY.indexOf("YOUR-ANON") === -1;

  var client = null;
  if (configured && window.supabase && window.supabase.createClient) {
    client = window.supabase.createClient(cfg.SUPABASE_URL, cfg.SUPABASE_ANON_KEY, {
      auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true }
    });
  }

  var MC = {
    client: client,
    configured: !!configured,
    config: cfg,

    /* ---- Sesion y perfil ---- */
    async getSession() {
      if (!client) return null;
      var r = await client.auth.getSession();
      return r.data ? r.data.session : null;
    },

    async getUser() {
      var s = await this.getSession();
      return s ? s.user : null;
    },

    async getProfile() {
      if (!client) return null;
      var user = await this.getUser();
      if (!user) return null;
      var r = await client
        .from("campus_profiles")
        .select("*")
        .eq("id", user.id)
        .maybeSingle();
      return r.data || null;
    },

    async isStaff() {
      var p = await this.getProfile();
      return !!p && (p.role === "moderator" || p.role === "admin");
    },

    async getEnrollments() {
      if (!client) return [];
      var r = await client.from("enrollments").select("course_id,status").eq("status", "active");
      return r.data || [];
    },

    /* ---- Guardas de navegacion ---- */
    // Exige sesion iniciada y email verificado; si no, redirige.
    async requireAuth() {
      var session = await this.getSession();
      if (!session) {
        location.href = "/campus/acceder/?next=" + encodeURIComponent(location.pathname + location.search);
        return null;
      }
      if (!session.user.email_confirmed_at && !session.user.confirmed_at) {
        location.href = "/campus/verificar/?pending=1";
        return null;
      }
      return session;
    },

    /* ---- Validacion de contrasena ---- */
    passwordChecks(pw) {
      pw = pw || "";
      return {
        length: pw.length >= 8,
        upper: /[A-Z]/.test(pw),
        lower: /[a-z]/.test(pw),
        symbol: /[^A-Za-z0-9]/.test(pw)
      };
    },
    passwordValid(pw) {
      var c = this.passwordChecks(pw);
      return c.length && c.upper && c.lower && c.symbol;
    },

    /* ---- Utilidades ---- */
    formatPrice(cents, currency) {
      try {
        return new Intl.NumberFormat("es-ES", {
          style: "currency",
          currency: currency || "EUR",
          minimumFractionDigits: 0,
          maximumFractionDigits: 2
        }).format((cents || 0) / 100);
      } catch (e) {
        return ((cents || 0) / 100).toFixed(0) + " " + (currency || "EUR");
      }
    },

    qs(name) {
      return new URLSearchParams(location.search).get(name);
    },

    // Escapa texto para insertarlo de forma segura en innerHTML (anti-XSS).
    esc(s) {
      return String(s == null ? "" : s)
        .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;").replace(/'/g, "&#39;");
    },

    // Solo permite URLs de vídeo embebido de orígenes de confianza.
    safeEmbed(url) {
      try {
        var u = new URL(url, location.origin);
        var ok = ["www.youtube.com", "youtube.com", "youtube-nocookie.com",
                  "player.vimeo.com", "vimeo.com"];
        if (u.protocol === "https:" && ok.indexOf(u.hostname) !== -1) return u.href;
      } catch (e) {}
      return null;
    },

    notConfiguredMessage() {
      return (
        "El campus aun no esta conectado a su base de datos. " +
        "Edita /campus/config.js con la URL y la anon key de Supabase " +
        "(instrucciones en /campus/README.md)."
      );
    }
  };

  // Mantiene la barra superior sincronizada con el estado de sesion.
  MC.refreshNav = async function () {
    var nav = document.getElementById("campusNav");
    if (!nav) return;
    var loggedLinks = nav.querySelectorAll("[data-auth='in']");
    var guestLinks = nav.querySelectorAll("[data-auth='out']");
    var session = MC.configured ? await MC.getSession() : null;
    var inSession = !!session;
    loggedLinks.forEach(function (el) { el.hidden = !inSession; });
    guestLinks.forEach(function (el) { el.hidden = inSession; });
    if (inSession) {
      var staffEls = nav.querySelectorAll("[data-auth='staff']");
      if (staffEls.length) {
        var staff = await MC.isStaff();
        staffEls.forEach(function (el) { el.hidden = !staff; });
      }
    }
  };

  MC.logout = async function () {
    if (client) await client.auth.signOut();
    location.href = "/campus/";
  };

  window.MC = MC;

  document.addEventListener("DOMContentLoaded", function () {
    MC.refreshNav();
    var out = document.querySelectorAll("[data-action='logout']");
    out.forEach(function (b) {
      b.addEventListener("click", function (e) { e.preventDefault(); MC.logout(); });
    });
    // Menú desplegable centrado, igual que la web principal: movemos el menú
    // al <body> (para que no herede el apilamiento de la barra) y añadimos un
    // velo de fondo. Solo aplica donde existe el botón hamburguesa.
    var toggle = document.getElementById("navToggle");
    var menu = document.getElementById("navMenu");
    if (toggle && menu) {
      if (menu.parentElement !== document.body) document.body.appendChild(menu);
      var backdrop = null;
      var setMenu = function (open) {
        menu.classList.toggle("open", open);
        toggle.setAttribute("aria-expanded", open ? "true" : "false");
        document.documentElement.classList.toggle("menu-open", open);
        if (open) {
          if (!backdrop) {
            backdrop = document.createElement("div");
            backdrop.className = "nav-backdrop";
            backdrop.addEventListener("click", function () { setMenu(false); });
            document.body.appendChild(backdrop);
          }
          requestAnimationFrame(function () { backdrop.classList.add("open"); });
        } else if (backdrop) {
          backdrop.classList.remove("open");
        }
      };
      toggle.addEventListener("click", function () { setMenu(!menu.classList.contains("open")); });
      menu.querySelectorAll("a").forEach(function (a) {
        a.addEventListener("click", function () { setMenu(false); });
      });
      document.addEventListener("keydown", function (e) { if (e.key === "Escape") setMenu(false); });
    }
  });
})();
