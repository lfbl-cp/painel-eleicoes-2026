// Popula e mantém coerentes os seletores a partir de output/index.json.
const NOMES_UNIDADE = {
  municipio: "Município",
  microrregiao: "Microrregião",
  mesorregiao: "Mesorregião",
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

  // Do mais votado pro menos votado, usando `pct_geral` (% do candidato
  // sobre o total de votos de todo o escopo — ver R/09_exportar.R), não
  // a ordem em que os candidatos aparecem no JSON.
  function popularCandidatos(resultado) {
    const select = document.getElementById("sel-candidato");
    const opcoes = Object.entries(resultado.candidatos)
      .map(([sq, c]) => ({ sq, label: `${c.nome} (${c.partido})`, pctGeral: c.pct_geral ?? 0 }))
      .sort((a, b) => b.pctGeral - a.pctGeral);

    select.innerHTML = "";
    opcoes.forEach(({ sq, label }) => {
      const opt = document.createElement("option");
      opt.value = sq;
      opt.textContent = label;
      select.appendChild(opt);
    });
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

  function renderizarLegenda({ modo, resultado, sqCandidato, porPartido }) {
    const container = document.getElementById("legenda");
    container.innerHTML = "";

    const linha = (cor, texto) => {
      const div = document.createElement("div");
      div.className = "item";
      div.innerHTML = `<span class="swatch" style="background:${cor}"></span><span>${texto}</span>`;
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

    if (modo === "lisa") {
      const tema = document.body.dataset.tema;
      Object.keys(Cores.PALETA_LISA.claro).forEach((cluster) => linha(Cores.corLisa(cluster, tema), cluster));
      return;
    }

    const candidato = resultado.candidatos[sqCandidato];
    linha(Cores.interpolarComBranco(candidato.cor, 0.15), "% baixo");
    linha(Cores.interpolarComBranco(candidato.cor, 1), "% alto");
  }

  return {
    popularCargos,
    popularUfs,
    popularTurnos,
    popularUnidades,
    popularCandidatos,
    atualizarVisibilidadeCandidato,
    atualizarDisponibilidadeLisa,
    renderizarLegenda,
  };
})();
