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
    THEME_KEY: "motex-theme",
    SESS_KEY: "motex-campus-sess",

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

    // Devuelve un Set con los ids de clases completadas por el usuario.
    async completedLessonIds() {
      if (!client) return new Set();
      var r = await client.from("lesson_progress").select("lesson_id").eq("completed", true);
      return new Set((r.data || []).map(function (x) { return x.lesson_id; }));
    },

    async markComplete(lessonId, courseId) {
      if (!client) return;
      var u = await this.getUser();
      if (!u) return;
      return client.from("lesson_progress").upsert(
        { user_id: u.id, lesson_id: lessonId, course_id: courseId, completed: true, completed_at: new Date().toISOString() },
        { onConflict: "user_id,lesson_id" }
      );
    },

    initials(p) {
      if (!p) return "·";
      var a = (p.first_name || p.username || "").trim()[0] || "";
      var b = (p.last_name || "").trim()[0] || "";
      return (a + b).toUpperCase() || (p.username || "U")[0].toUpperCase();
    },

    fillAvatar(el, p) {
      if (!el) return;
      if (p && p.avatar_url) { el.innerHTML = '<img src="' + this.esc(p.avatar_url) + '" alt="">'; }
      else { el.textContent = this.initials(p); }
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
      var ok = await this.enforceSingleSession();
      if (!ok) return null;
      return session;
    },

    /* ---- Sesión única por cuenta (anti cuentas compartidas) ---- */
    newToken() {
      return (window.crypto && crypto.randomUUID) ? crypto.randomUUID()
        : String(Date.now()) + "-" + Math.random().toString(16).slice(2);
    },

    // Reclama el dispositivo activo (se llama al iniciar sesión).
    async claimSession() {
      if (!client) return;
      var u = await this.getUser();
      if (!u) return;
      var token = this.newToken();
      localStorage.setItem(this.SESS_KEY, token);
      await client.from("campus_profiles").update({ active_session: token }).eq("id", u.id);
    },

    // Verifica que este dispositivo siga siendo el activo. Si la cuenta
    // tiene el curso de empresas (equipo), no se aplica el límite.
    async enforceSingleSession() {
      if (!client) return true;
      try {
        var team = await client.rpc("campus_has_team_access");
        if (team && team.data) return true;
      } catch (e) { return true; }
      var profile = await this.getProfile();
      if (!profile) return true;
      var local = localStorage.getItem(this.SESS_KEY);
      if (!profile.active_session) {
        if (!local) { local = this.newToken(); localStorage.setItem(this.SESS_KEY, local); }
        await client.from("campus_profiles").update({ active_session: local }).eq("id", profile.id);
        return true;
      }
      if (local && local === profile.active_session) return true;
      await client.auth.signOut();
      location.href = "/campus/acceder/?kicked=1";
      return false;
    },

    /* ---- Tema claro / oscuro ---- */
    currentTheme() { return localStorage.getItem(this.THEME_KEY) || "dark"; },
    applyTheme(t) { document.documentElement.setAttribute("data-theme", t === "light" ? "light" : "dark"); },
    setTheme(t) { localStorage.setItem(this.THEME_KEY, t); this.applyTheme(t); this.syncThemeButtons(); },
    toggleTheme() { this.setTheme(this.currentTheme() === "light" ? "dark" : "light"); },
    syncThemeButtons() {
      var self = this;
      document.querySelectorAll("[data-theme-toggle]").forEach(function (b) {
        b.textContent = self.currentTheme() === "light" ? "🌙" : "☀";
        b.setAttribute("aria-label", "Cambiar a tema " + (self.currentTheme() === "light" ? "oscuro" : "claro"));
      });
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
    // Búsqueda en todo el documento: el menú puede haberse movido al <body>.
    var loggedLinks = document.querySelectorAll("[data-auth='in']");
    var guestLinks = document.querySelectorAll("[data-auth='out']");
    if (!loggedLinks.length && !guestLinks.length) return;
    var session = MC.configured ? await MC.getSession() : null;
    var inSession = !!session;
    loggedLinks.forEach(function (el) { el.hidden = !inSession; });
    guestLinks.forEach(function (el) { el.hidden = inSession; });
    if (inSession) {
      var staffEls = document.querySelectorAll("[data-auth='staff']");
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
    MC.applyTheme(MC.currentTheme());
    // Botón flotante de tema si la página no trae uno propio.
    if (!document.querySelector("[data-theme-toggle]")) {
      var fab = document.createElement("button");
      fab.type = "button";
      fab.className = "theme-fab";
      fab.setAttribute("data-theme-toggle", "");
      document.body.appendChild(fab);
    }
    MC.syncThemeButtons();
    document.querySelectorAll("[data-theme-toggle]").forEach(function (b) {
      b.addEventListener("click", function (e) { e.preventDefault(); MC.toggleTheme(); });
    });
    MC.refreshNav();
    var out = document.querySelectorAll("[data-action='logout']");
    out.forEach(function (b) {
      b.addEventListener("click", function (e) { e.preventDefault(); MC.logout(); });
    });
    // Barra lateral del espacio privado: marcar enlace activo + menú móvil.
    var sidebar = document.querySelector(".app-sidebar");
    if (sidebar) {
      var active = document.body.getAttribute("data-active");
      sidebar.querySelectorAll("a[data-side]").forEach(function (a) {
        if (a.getAttribute("data-side") === active) a.classList.add("active");
      });
      var burger = document.querySelector(".app-burger");
      var back = document.querySelector(".app-backdrop");
      var close = function () { sidebar.classList.remove("open"); if (back) back.classList.remove("open"); };
      if (burger) burger.addEventListener("click", function () {
        sidebar.classList.toggle("open"); if (back) back.classList.toggle("open");
      });
      if (back) back.addEventListener("click", close);
      sidebar.querySelectorAll("a").forEach(function (a) { a.addEventListener("click", close); });
    }

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
