// Popula e mantém coerentes os seletores a partir de output/index.json.
// "uf" fica de fora por enquanto — ainda não exportamos um TopoJSON de
// contorno estadual (só faz sentido em escala nacional, com as 27 UFs).
const NOMES_UNIDADE = {
  municipio: "Município",
  microrregiao: "Microrregião",
  mesorregiao: "Mesorregião",
};

const Seletores = (() => {
  function preencher(select, opcoes, formatarLabel = (v) => v) {
    select.innerHTML = "";
    opcoes.forEach((valor) => {
      const opt = document.createElement("option");
      opt.value = valor;
      opt.textContent = formatarLabel(valor);
      select.appendChild(opt);
    });
  }

  function popularCargos(entradas) {
    const cargos = [...new Set(entradas.map((e) => e.cargo))];
    preencher(document.getElementById("sel-cargo"), cargos);
  }

  function popularTurnos(entradas, cargo) {
    const turnos = [...new Set(entradas.filter((e) => e.cargo === cargo).map((e) => e.turno))].sort();
    preencher(document.getElementById("sel-turno"), turnos, (t) => `${t}º turno`);
  }

  function popularUnidades(entradas, cargo, turno) {
    const unidades = [...new Set(entradas.filter((e) => e.cargo === cargo && e.turno === turno).map((e) => e.unidade))].filter(
      (u) => u !== "uf"
    );
    preencher(document.getElementById("sel-unidade"), unidades, (u) => NOMES_UNIDADE[u] || u);
  }

  function popularCandidatos(resultado) {
    const select = document.getElementById("sel-candidato");
    const opcoes = Object.entries(resultado.candidatos).map(([sq, c]) => ({
      sq,
      label: `${c.nome} (${c.partido})`,
    }));

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

  function atualizarDisponibilidadeLisa(unidade) {
    const opcaoLisa = document.querySelector('#sel-modo option[value="lisa"]');
    const habilitado = unidade === "municipio";
    opcaoLisa.disabled = !habilitado;
    if (!habilitado && document.getElementById("sel-modo").value === "lisa") {
      document.getElementById("sel-modo").value = "vencedor";
    }
  }

  function renderizarLegenda({ modo, resultado, sqCandidato }) {
    const container = document.getElementById("legenda");
    container.innerHTML = "";

    const linha = (cor, texto) => {
      const div = document.createElement("div");
      div.className = "item";
      div.innerHTML = `<span class="swatch" style="background:${cor}"></span><span>${texto}</span>`;
      container.appendChild(div);
    };

    if (modo === "vencedor") {
      const vistos = new Set();
      Object.values(resultado.vencedores).forEach((v) => {
        if (vistos.has(v.nome)) return;
        vistos.add(v.nome);
        linha(Cores.escurecer(v.cor, 0.25), `${v.nome} (${v.partido})`);
      });
      const nota = document.createElement("div");
      nota.className = "legenda-nota";
      nota.textContent = "Tom mais escuro = vitória por margem maior. Tom mais claro = margem menor.";
      container.appendChild(nota);
      return;
    }

    if (modo === "lisa") {
      Object.entries(Cores.PALETA_LISA).forEach(([cluster, cor]) => linha(cor, cluster));
      return;
    }

    const candidato = resultado.candidatos[sqCandidato];
    linha(Cores.interpolarComBranco(candidato.cor, 0.15), "% baixo");
    linha(Cores.interpolarComBranco(candidato.cor, 1), "% alto");
  }

  return {
    popularCargos,
    popularTurnos,
    popularUnidades,
    popularCandidatos,
    atualizarVisibilidadeCandidato,
    atualizarDisponibilidadeLisa,
    renderizarLegenda,
  };
})();
