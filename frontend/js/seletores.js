// Popula e mantém coerentes os seletores a partir de output/index.json.
const NOMES_UNIDADE = {
  municipio: "Município",
  microrregiao: "Microrregião",
  mesorregiao: "Mesorregião",
  uf: "UF",
};

// "BR" é o pseudo-UF de abrangência nacional (ver R/01_aquisicao.R): pra
// Presidente é a única opção real; pra Governador/Senador é o "mosaico"
// dos resultados de todas as UFs juntos (cada uma com sua própria
// eleição — ver `montar_mosaico_nacional()` em pipeline/run_pipeline.R).
const NOMES_UF = {
  BR: "Brasil",
  AC: "Acre", AL: "Alagoas", AM: "Amazonas", AP: "Amapá", BA: "Bahia",
  CE: "Ceará", DF: "Distrito Federal", ES: "Espírito Santo", GO: "Goiás",
  MA: "Maranhão", MG: "Minas Gerais", MS: "Mato Grosso do Sul",
  MT: "Mato Grosso", PA: "Pará", PB: "Paraíba", PE: "Pernambuco",
  PI: "Piauí", PR: "Paraná", RJ: "Rio de Janeiro",
  RN: "Rio Grande do Norte", RO: "Rondônia", RR: "Roraima",
  RS: "Rio Grande do Sul", SC: "Santa Catarina", SE: "Sergipe",
  SP: "São Paulo", TO: "Tocantins",
};

const Seletores = (() => {
  // Repopula um <select> preservando a seleção atual quando ela ainda é
  // uma opção válida — sem isso, trocar de Cargo sempre fazia a UF
  // voltar pra primeira da lista (Acre), mesmo se o usuário só queria
  // trocar o cargo mantendo o estado que já estava vendo. `preferido`
  // força um valor específico em vez de preservar o atual — só usado no
  // carregamento inicial (Cargo=Presidente, UF=Brasil por padrão).
  function preencher(select, opcoes, formatarLabel = (v) => v, preferido) {
    const alvo = preferido !== undefined ? preferido : select.value;
    select.innerHTML = "";
    opcoes.forEach((valor) => {
      const opt = document.createElement("option");
      opt.value = valor;
      opt.textContent = formatarLabel(valor);
      select.appendChild(opt);
    });
    if (opcoes.some((v) => String(v) === String(alvo))) {
      select.value = alvo;
    }
  }

  // Eleição mais recente primeiro.
  function popularAnos(entradas, preferido) {
    const anos = [...new Set(entradas.map((e) => e.ano))].sort((a, b) => b - a);
    preencher(document.getElementById("sel-ano"), anos, undefined, preferido);
  }

  function popularCargos(entradas, preferido) {
    const cargos = [...new Set(entradas.map((e) => e.cargo))];
    preencher(document.getElementById("sel-cargo"), cargos, undefined, preferido);
  }

  // "BR" (Brasil) sempre primeiro — as demais UFs em ordem alfabética.
  function popularUfs(entradas, cargo, preferido) {
    const ufs = [...new Set(entradas.filter((e) => e.cargo === cargo).map((e) => e.uf))].sort((a, b) => {
      if (a === "BR") return -1;
      if (b === "BR") return 1;
      return a.localeCompare(b);
    });
    preencher(document.getElementById("sel-uf"), ufs, (uf) => NOMES_UF[uf] || uf, preferido);
  }

  function popularTurnos(entradas, cargo, uf) {
    const turnos = [...new Set(entradas.filter((e) => e.cargo === cargo && e.uf === uf).map((e) => e.turno))].sort();
    preencher(document.getElementById("sel-turno"), turnos, (t) => `${t}º turno`);
  }

  function popularUnidades(entradas, cargo, uf, turno) {
    const unidades = [
      ...new Set(entradas.filter((e) => e.cargo === cargo && e.uf === uf && e.turno === turno).map((e) => e.unidade)),
    ];
    preencher(document.getElementById("sel-unidade"), unidades, (u) => NOMES_UNIDADE[u] || u);
  }

  // Do mais votado pro menos votado. `ordem` (SQs na ordem do ranking do
  // escopo, ver R/11_candidatos.R) resolve o Presidente filtrado por UF, cujo
  // `pct_geral` é nacional; sem ela (ou pra quem não está nela), vale o
  // `pct_geral` (% sobre o total de votos do escopo — ver R/09_exportar.R).
  // Mantém o candidato selecionado quando ele continua na lista.
  function popularCandidatos(resultado, ordem = []) {
    const select = document.getElementById("sel-candidato");
    const anterior = select.value;
    const posicao = new Map(ordem.map((sq, i) => [sq, i]));
    const opcoes = Object.entries(resultado.candidatos)
      .map(([sq, c]) => ({ sq, label: `${c.nome} (${c.partido})`, pctGeral: c.pct_geral ?? 0, pos: posicao.get(sq) ?? Infinity }))
      .sort((a, b) => a.pos - b.pos || b.pctGeral - a.pctGeral);

    select.innerHTML = "";
    opcoes.forEach(({ sq, label }) => {
      const opt = document.createElement("option");
      opt.value = sq;
      opt.textContent = label;
      select.appendChild(opt);
    });
    if (opcoes.some((o) => o.sq === anterior)) select.value = anterior;
  }

  // Botões do candidato no swing (um por candidato do par, ver
  // R/10_swing.R), com `ativo` marcado. `aoEscolher(chave)` é chamado no clique.
  function popularCandidatosSwing(resultado, ativo, aoEscolher) {
    const container = document.getElementById("swing-candidatos");
    container.innerHTML = "";
    Object.entries(resultado.candidatos).forEach(([chave, c]) => {
      const botao = document.createElement("button");
      botao.type = "button";
      botao.textContent = c.rotulo;
      botao.setAttribute("aria-pressed", String(chave === ativo));
      botao.addEventListener("click", () => aoEscolher(chave));
      container.appendChild(botao);
    });
  }

  // No swing, os filtros de Eleição/Cargo/Turno/Modo/Candidato não se
  // aplicam (é sempre Presidente, 1º turno, ano atual vs. ano base) — só
  // UF e Unidade continuam valendo.
  function atualizarVisibilidadeSwing(ativo) {
    ["label-ano", "label-cargo", "label-turno", "label-modo"].forEach((id) =>
      document.getElementById(id).classList.toggle("oculto", ativo)
    );
    document.getElementById("swing-controles").classList.toggle("oculto", !ativo);
    if (ativo) document.getElementById("label-candidato").classList.add("oculto");
    const botao = document.getElementById("btn-swing");
    botao.setAttribute("aria-pressed", String(ativo));
  }

  function atualizarVisibilidadeCandidato(modo) {
    document.getElementById("label-candidato").classList.toggle("oculto", modo === "vencedor");
  }

  // `lisaDisponivel` vem direto da entrada do index.json (campo
  // `lisa_disponivel`) — não é só "unidade === município": Presidente
  // filtrado por UF e o mosaico nacional de Governador/Senador também
  // são município, mas não têm LISA disponível (ver CLAUDE.md).
  function atualizarDisponibilidadeLisa(lisaDisponivel) {
    const opcaoLisa = document.querySelector('#sel-modo option[value="lisa"]');
    opcaoLisa.disabled = !lisaDisponivel;
    if (!lisaDisponivel && document.getElementById("sel-modo").value === "lisa") {
      document.getElementById("sel-modo").value = "vencedor";
    }
  }

  // `idsUnidades`: códigos das unidades desenhadas no mapa (pra contar os
  // clusters do LISA só da geometria visível).
  function renderizarLegenda({ modo, resultado, sqCandidato, porPartido, idsUnidades = [] }) {
    const container = document.getElementById("legenda");
    container.innerHTML = "";

    const linha = (cor, texto, n) => {
      const div = document.createElement("div");
      div.className = "item";
      div.innerHTML =
        `<span class="swatch" style="background:${cor}"></span><span>${texto}</span>` + (n != null ? `<span class="n">${n}</span>` : "");
      container.appendChild(div);
    };

    if (modo === "vencedor") {
      // Governador/Senador com UF = Brasil é um mosaico de 27 eleições
      // diferentes — legenda por candidato teria uma linha por UF
      // (dezenas). Agrupar por partido (`porPartido`, ver main.js) fica
      // legível e ainda mostra o padrão geral de quem venceu onde.
      const vistos = new Set();
      Object.values(resultado.vencedores).forEach((v) => {
        const chave = porPartido ? v.partido : v.nome;
        if (vistos.has(chave)) return;
        vistos.add(chave);
        const rotulo = porPartido ? v.partido : `${v.nome} (${v.partido})`;
        linha(Cores.escurecer(v.cor, 0.25), rotulo);
      });
      const nota = document.createElement("div");
      nota.className = "legenda-nota";
      nota.textContent = "Tom mais escuro = vitória por margem maior. Tom mais claro = margem menor.";
      container.appendChild(nota);
      return;
    }

    if (modo === "swing") {
      const c = resultado.candidatos[sqCandidato];
      const adversario = Object.entries(resultado.candidatos).find(([k]) => k !== sqCandidato)[1];
      const max = resultado.escala_max;
      const meio = Cores.interpolarComBranco(c.cor, 0);
      const escala = document.createElement("div");
      escala.className = "escala-divergente";
      escala.innerHTML =
        `<div class="barra" style="background:linear-gradient(to right, ${adversario.cor}, ${meio}, ${c.cor})"></div>` +
        `<div class="rotulos"><span>−${max} p.p.</span><span>0</span><span>+${max} p.p.</span></div>`;
      container.appendChild(escala);

      const resumo = document.createElement("div");
      resumo.className = "swing-resumo";
      resumo.innerHTML =
        `<b>Brasil:</b> ${c.nome_base} ${c.pct_geral_base.toFixed(1)}% (${resultado.ano_base}) → ` +
        `${c.rotulo} ${c.pct_geral.toFixed(1)}% (${resultado.ano}): <b>${Mapa.formatarSwing(c.swing_geral)}</b>`;
      container.appendChild(resumo);

      const nota = document.createElement("div");
      nota.className = "legenda-nota";
      nota.textContent =
        `Swing = % dos votos válidos no 1º turno de ${resultado.ano} − % no 1º turno de ${resultado.ano_base}. ` +
        (c.nome_base !== c.nome ? `Base de ${c.rotulo}: ${c.nome_base} (${resultado.ano_base}). ` : "") +
        `Cor de ${c.rotulo} = ganho; cor de ${adversario.rotulo} = perda. Escala saturada em ±${max} p.p.`;
      container.appendChild(nota);
      return;
    }

    // Tipologia de Terron (2009), com a contagem de unidades em cada classe
    // -- mesmo modelo do Dashboard-legislativo-2026.
    if (modo === "lisa") {
      const tema = document.body.dataset.tema;
      const lisa = (resultado.candidatos[sqCandidato] || {}).lisa || {};
      const cont = {};
      idsUnidades.forEach((id) => {
        const cl = lisa[id];
        if (cl) cont[cl] = (cont[cl] || 0) + 1;
      });
      Object.keys(Cores.NOMES_LISA).forEach((cluster) =>
        linha(Cores.corLisa(cluster, tema), Cores.nomeLisa(cluster), (cont[cluster] || 0).toLocaleString("pt-BR"))
      );
      const nota = document.createElement("div");
      nota.className = "legenda-nota";
      nota.textContent =
        "Tipologia de Terron (2009) sobre o Moran local do % dos válidos por município (vizinhança queen, " +
        "199 permutações, p < 0,05). Território forte: votação alta cercada de municípios também altos; " +
        "território fraco: baixa cercada de baixos; forte isolado: alta cercada de baixos; fraco isolado: " +
        "baixa cercada de altos.";
      container.appendChild(nota);
      return;
    }

    const candidato = resultado.candidatos[sqCandidato];
    linha(Cores.interpolarComBranco(candidato.cor, 0.15), "% baixo");
    linha(Cores.interpolarComBranco(candidato.cor, 1), "% alto");
  }

  return {
    popularAnos,
    popularCargos,
    popularCandidatosSwing,
    atualizarVisibilidadeSwing,
    popularUfs,
    popularTurnos,
    popularUnidades,
    popularCandidatos,
    atualizarVisibilidadeCandidato,
    atualizarDisponibilidadeLisa,
    renderizarLegenda,
  };
})();
