// Painel flutuante da direita, no modelo do Dashboard-legislativo-2026
// (card.js + painel_mapa.js de lá): no modo Vencedor, ranking dos mais
// votados do escopo (cargo/turno/UF) com foto; nos modos de candidato
// (contínuo, LISA, swing), o card do candidato. Os dados vêm de
// output/candidatos/{ano}.json (R/11_candidatos.R) e as fotos de
// output/fotos/{ano}/{sq}.jpg.
const PainelDireito = (() => {
  const N_RANKING = 10;
  const HOSTS_REDES = {
    "instagram.com": "Instagram", "facebook.com": "Facebook", "fb.com": "Facebook",
    "tiktok.com": "TikTok", "twitter.com": "X/Twitter", "x.com": "X/Twitter",
    "youtube.com": "YouTube", "threads.com": "Threads", "threads.net": "Threads",
    "kwai.com": "Kwai", "linkedin.com": "LinkedIn", "linktr.ee": "Linktree",
  };
  const CONECTIVOS = new Set(["de", "da", "do", "das", "dos", "e"]);

  const el = (id) => document.getElementById(id);
  const esc = (s) =>
    String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);
  const inteiro = (n) => Math.round(n).toLocaleString("pt-BR");
  const pct = (p) => `${p.toLocaleString("pt-BR", { minimumFractionDigits: 1, maximumFractionDigits: 1 })}%`;
  // "TORNEIRO MECÂNICO" -> "Torneiro mecânico" (o TSE manda em CAIXA ALTA).
  const capitalizar = (s) => (s ? s.charAt(0).toUpperCase() + s.slice(1).toLowerCase() : s);
  const iniciais = (nome) =>
    nome
      .split(/\s+/)
      .filter((p) => p && !CONECTIVOS.has(p.toLowerCase()))
      .slice(0, 2)
      .map((p) => p[0].toUpperCase())
      .join("");

  function htmlIniciais(ini, cor) {
    return `<div class="foto-iniciais" style="background:${esc(cor)}">${esc(ini)}</div>`;
  }

  // Sem foto (ou se a imagem falhar -- ver instalarFallbackFotos), mostra as
  // iniciais sobre a cor do partido.
  function htmlFoto(ano, sq, c, cor) {
    const ini = iniciais(c.nome);
    if (!c.foto) return htmlIniciais(ini, cor);
    return `<img class="foto" src="${Dados.urlFoto(ano, esc(sq))}" alt="" loading="lazy"
      data-iniciais="${esc(ini)}" data-cor="${esc(cor)}">`;
  }

  // Erro de <img> não borbulha; captura no documento troca qualquer foto
  // quebrada pelas iniciais. Chamado uma vez em iniciar().
  function instalarFallbackFotos() {
    document.addEventListener(
      "error",
      (ev) => {
        const img = ev.target;
        if (img instanceof HTMLImageElement && img.classList.contains("foto")) {
          img.outerHTML = htmlIniciais(img.dataset.iniciais, img.dataset.cor);
        }
      },
      true
    );
  }

  function rotuloRede(url) {
    const host = url.replace(/^[a-z]+:\/\//i, "").split(/[/?#]/)[0].toLowerCase();
    const conhecido = Object.keys(HOSTS_REDES).find((h) => host === h || host.endsWith(`.${h}`));
    return conhecido ? HOSTS_REDES[conhecido] : host.replace(/^www\./, "");
  }

  function nomeEscopo(uf) {
    return NOMES_UF[uf] || uf;
  }

  // --- card ---------------------------------------------------------------------
  function htmlCard({ ano, sq, c, cor, turno, uf, linhaEscopo, posicao }) {
    const situacao = (c.situacao || {})[turno];
    const votos = (c.votos || {})[turno];
    const linhas = [
      ["Cargo", c.uf === "BR" ? c.cargo : `${c.cargo} · ${nomeEscopo(c.uf)}`],
      ["Votos", votos != null ? `${inteiro(votos)} (${turno}º turno)` : null],
      // Presidente visto numa UF: desempenho naquela UF, além do nacional.
      [
        `Em ${nomeEscopo(uf)}`,
        linhaEscopo && uf !== c.uf ? `${pct(linhaEscopo.pct)} · ${inteiro(linhaEscopo.votos)} votos · ${posicao}º lugar` : null,
      ],
      ["Número", c.numero],
      ["Idade", c.idade != null ? `${c.idade} anos` : null],
      ["Gênero", capitalizar(c.genero)],
      ["Ocupação", capitalizar(c.ocupacao)],
      ["Instrução", capitalizar(c.instrucao)],
      ["Coligação", c.coligacao],
    ].filter(([, v]) => v !== null && v !== undefined && v !== "");
    const redes = (c.redes || [])
      .filter((u) => /^https?:\/\//i.test(u))
      .map((u) => `<a href="${esc(u)}" target="_blank" rel="noopener noreferrer">${esc(rotuloRede(u))}</a>`)
      .join("");

    return `
      <div class="card-topo">
        ${htmlFoto(ano, sq, c, cor)}
        <div>
          <p class="card-nome">${esc(c.nome)}</p>
          <p class="card-sub">${esc(c.nome_completo)}</p>
          <span class="card-partido"><span class="swatch" style="background:${esc(cor)}"></span>${esc(c.partido)}</span>
          ${situacao ? `<div class="card-sub">${esc(situacao)} · ${ano}</div>` : ""}
        </div>
      </div>
      <dl class="card-dados">${linhas.map(([k, v]) => `<dt>${esc(k)}</dt><dd>${esc(v)}</dd>`).join("")}</dl>
      ${redes ? `<div class="card-redes">${redes}</div>` : ""}`;
  }

  // --- ranking ------------------------------------------------------------------
  function htmlLinhaRanking({ ano, linha, pos, c, cor, turno, mostrarUf }) {
    const eleito = (c.situacao || {})[turno] === "Eleito";
    const sit = (c.situacao || {})[turno] || "";
    const ufTxt = mostrarUf ? ` · ${esc(c.uf)}` : "";
    return `<li data-sq="${esc(linha.sq)}" data-uf="${esc(c.uf)}" tabindex="0" class="${eleito ? "rk-eleito" : ""}" title="Ver no mapa">
      <span class="rk-pos">${pos}</span>
      ${htmlFoto(ano, linha.sq, c, cor)}
      <span><span class="rk-nome">${esc(c.nome)}</span>
        <span class="rk-sub"><span class="swatch" style="background:${esc(cor)}"></span>${esc(c.partido)}${ufTxt}${sit ? ` · ${esc(sit)}` : ""}</span></span>
      <span class="rk-num"><b>${pct(linha.pct)}</b><span>${inteiro(linha.votos)}</span></span>
    </li>`;
  }

  function htmlRanking({ ano, dados, linhas, cargo, turno, uf, corDe }) {
    const mosaico = uf === "BR" && cargo !== "Presidente";
    const comPos = linhas.map((l, k) => ({ linha: l, pos: k + 1, c: dados.candidatos[l.sq] })).filter((x) => x.c);
    const item = (x) => htmlLinhaRanking({ ano, linha: x.linha, pos: x.pos, c: x.c, cor: corDe(x.linha.sq), turno, mostrarUf: mosaico });
    const lista = (xs) => `<ol class="ranking">${xs.map(item).join("")}</ol>`;

    let html;
    if (comPos.length === 0) {
      html = `<p class="legenda-nota">Sem ranking para esta combinação.</p>`;
    } else if (cargo === "Senador" && comPos.some((x) => x.c.situacao[turno] === "Eleito")) {
      // Senado: eleitos primeiro (em 2026 são 2 por UF), depois os demais.
      const eleitos = comPos.filter((x) => x.c.situacao[turno] === "Eleito");
      const demais = comPos.filter((x) => x.c.situacao[turno] !== "Eleito").slice(0, N_RANKING);
      html = `<div class="ranking-secao">Eleitos</div>${lista(eleitos)}${
        demais.length ? `<div class="ranking-secao">Demais candidatos</div>${lista(demais)}` : ""
      }`;
    } else {
      html = lista(comPos.slice(0, N_RANKING));
    }
    const nota = mosaico
      ? "% sobre os votos válidos da UF de cada candidato (cada UF tem a sua eleição)."
      : cargo === "Presidente" && uf === "BR"
        ? "% sobre os votos válidos do Brasil, incluindo o exterior."
        : "";
    return html + (nota ? `<p class="legenda-nota">${nota}</p>` : "");
  }

  // --- API ----------------------------------------------------------------------
  let pedido = 0;

  // `modo`: "vencedor" -> ranking; demais -> card de `sq`. `corDe(sq)`: cor
  // do partido do candidato (vem do resultado do mapa). `aoAbrir(sq, uf)`:
  // clique numa linha do ranking.
  async function renderizar({ ano, cargo, turno, uf, modo, sq, corDe, aoAbrir }) {
    const meu = ++pedido;
    const painel = el("painel-direito");
    let dados;
    try {
      dados = await Dados.carregarCandidatos(ano);
    } catch (e) {
      dados = null;
    }
    if (meu !== pedido) return;
    if (!dados) {
      painel.hidden = true;
      return;
    }

    const linhas = (((dados.ranking[cargo] || {})[String(turno)] || {})[uf]) || [];
    const titulo = el("direito-titulo");
    const conteudo = el("direito-conteudo");

    if (modo === "vencedor") {
      titulo.innerHTML = `Mais votados <span class="sub">${esc(cargo)} · ${turno}º turno · ${esc(nomeEscopo(uf))} · ${ano}</span>`;
      conteudo.innerHTML = htmlRanking({ ano, dados, linhas, cargo, turno, uf, corDe });
      conteudo.querySelectorAll("li[data-sq]").forEach((li) => {
        const abrir = () => aoAbrir(li.dataset.sq, li.dataset.uf);
        li.addEventListener("click", abrir);
        li.addEventListener("keydown", (ev) => {
          if (ev.key === "Enter" || ev.key === " ") {
            ev.preventDefault();
            abrir();
          }
        });
      });
      painel.hidden = false;
      return;
    }

    const c = dados.candidatos[sq];
    if (!c) {
      painel.hidden = true;
      return;
    }
    const posicao = linhas.findIndex((l) => l.sq === sq);
    titulo.innerHTML = "";
    conteudo.innerHTML = htmlCard({
      ano, sq, c, cor: corDe(sq), turno, uf,
      linhaEscopo: posicao >= 0 ? linhas[posicao] : null,
      posicao: posicao + 1,
    });
    painel.hidden = false;
  }

  // Ordem do mais ao menos votado no escopo (pro seletor de candidato).
  async function ordemCandidatos(ano, cargo, turno, uf) {
    try {
      const dados = await Dados.carregarCandidatos(ano);
      return ((((dados.ranking[cargo] || {})[String(turno)] || {})[uf]) || []).map((l) => l.sq);
    } catch (e) {
      return [];
    }
  }

  // No celular (≤ 700px) o painel da direita entra no fim do painel
  // principal; no desktop flutua à direita.
  function posicionar() {
    const painel = el("painel-direito");
    const celular = window.matchMedia("(max-width: 700px)");
    const aplicar = () => {
      if (celular.matches) el("controles").appendChild(painel);
      else document.body.appendChild(painel);
    };
    celular.addEventListener("change", aplicar);
    aplicar();
  }

  function iniciar() {
    instalarFallbackFotos();
    posicionar();
    const painel = el("painel-direito");
    L.DomEvent.disableClickPropagation(painel);
    L.DomEvent.disableScrollPropagation(painel);
  }

  return { iniciar, renderizar, ordemCandidatos };
})();
