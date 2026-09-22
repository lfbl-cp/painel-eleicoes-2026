// Orquestração: liga os seletores aos dados e ao mapa.
(async function main() {
  const selCargo = document.getElementById("sel-cargo");
  const selTurno = document.getElementById("sel-turno");
  const selUnidade = document.getElementById("sel-unidade");
  const selModo = document.getElementById("sel-modo");
  const selCandidato = document.getElementById("sel-candidato");
  const status = document.getElementById("status");

  let estadoAtual = { topo: null, resultado: null, unidade: null };

  function entradaSelecionada(entradas) {
    return entradas.find(
      (e) => e.cargo === selCargo.value && e.turno === Number(selTurno.value) && e.unidade === selUnidade.value
    );
  }

  function renderizarComEstadoAtual() {
    if (!estadoAtual.topo || !estadoAtual.resultado) return;
    Mapa.renderizar({
      topo: estadoAtual.topo,
      resultado: estadoAtual.resultado,
      unidade: estadoAtual.unidade,
      modo: selModo.value,
      sqCandidato: selCandidato.value,
    });
    Seletores.renderizarLegenda({
      modo: selModo.value,
      resultado: estadoAtual.resultado,
      sqCandidato: selCandidato.value,
    });
  }

  async function carregarDadosDaSelecao() {
    const entradas = Dados.entradas();
    const entrada = entradaSelecionada(entradas);
    if (!entrada) {
      status.textContent = "Combinação sem dados exportados.";
      return;
    }

    status.textContent = "Carregando...";
    const [topo, resultado] = await Promise.all([
      Dados.carregarGeo(entrada.arquivo_geo),
      Dados.carregarResultado(entrada.arquivo_resultado),
    ]);

    estadoAtual = { topo, resultado, unidade: entrada.unidade };
    Seletores.popularCandidatos(resultado);
    Seletores.atualizarDisponibilidadeLisa(entrada.unidade);
    Seletores.atualizarVisibilidadeCandidato(selModo.value);
    renderizarComEstadoAtual();
    status.textContent = "";
  }

  selCargo.addEventListener("change", () => {
    Seletores.popularTurnos(Dados.entradas(), selCargo.value);
    selTurno.dispatchEvent(new Event("change"));
  });

  selTurno.addEventListener("change", () => {
    Seletores.popularUnidades(Dados.entradas(), selCargo.value, Number(selTurno.value));
    selUnidade.dispatchEvent(new Event("change"));
  });

  selUnidade.addEventListener("change", carregarDadosDaSelecao);

  selModo.addEventListener("change", () => {
    Seletores.atualizarVisibilidadeCandidato(selModo.value);
    renderizarComEstadoAtual();
  });

  selCandidato.addEventListener("change", renderizarComEstadoAtual);

  Mapa.iniciar();
  Tema.iniciar();

  // O painel flutua sobre o mapa Leaflet — sem isso, clicar/rolar dentro
  // dele também arrasta/dá zoom no mapa por baixo.
  const painel = document.getElementById("controles");
  L.DomEvent.disableClickPropagation(painel);
  L.DomEvent.disableScrollPropagation(painel);

  status.textContent = "Carregando índice...";
  await Dados.carregarIndice();
  Seletores.popularCargos(Dados.entradas());
  selCargo.dispatchEvent(new Event("change"));
})();
