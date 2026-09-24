// Orquestração: liga os seletores aos dados e ao mapa.
(async function main() {
  const selCargo = document.getElementById("sel-cargo");
  const selUf = document.getElementById("sel-uf");
  const selTurno = document.getElementById("sel-turno");
  const selUnidade = document.getElementById("sel-unidade");
  const selModo = document.getElementById("sel-modo");
  const selCandidato = document.getElementById("sel-candidato");
  const status = document.getElementById("status");

  let estadoAtual = { topo: null, resultado: null, unidade: null, cargo: null, uf: null, topoContornoUf: null };

  function entradaSelecionada(entradas) {
    return entradas.find(
      (e) =>
        e.cargo === selCargo.value &&
        e.uf === selUf.value &&
        e.turno === Number(selTurno.value) &&
        e.unidade === selUnidade.value
    );
  }

  // Governador/Senador com UF = Brasil é um mosaico dos resultados de
  // cada UF (candidatos diferentes em cada uma) — nesse caso a legenda
  // agrupa por partido em vez de por candidato (ver seletores.js).
  function legendaPorPartido() {
    return (estadoAtual.cargo === "Governador" || estadoAtual.cargo === "Senador") && estadoAtual.uf === "BR";
  }

  function renderizarComEstadoAtual() {
    if (!estadoAtual.topo || !estadoAtual.resultado) return;
    Mapa.renderizar({
      topo: estadoAtual.topo,
      resultado: estadoAtual.resultado,
      unidade: estadoAtual.unidade,
      modo: selModo.value,
      sqCandidato: selCandidato.value,
      topoContornoUf: estadoAtual.topoContornoUf,
    });
    Seletores.renderizarLegenda({
      modo: selModo.value,
      resultado: estadoAtual.resultado,
      sqCandidato: selCandidato.value,
      porPartido: legendaPorPartido(),
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
    // Contorno de UF por cima da unidade ativa (ver Mapa.renderizarContornoUf) —
    // dispensável quando a própria unidade já é "uf" (mesmo arquivo da layer
    // principal). O caminho segue a mesma convenção de nome de
    // `pipeline/run_pipeline.R` (`ufs_{uf}.topojson`), sem precisar caçar a
    // entrada correspondente no índice.
    const precisaContornoUf = entrada.unidade !== "uf";
    const [topo, resultado, topoContornoUf] = await Promise.all([
      Dados.carregarGeo(entrada.arquivo_geo),
      Dados.carregarResultado(entrada.arquivo_resultado),
      precisaContornoUf ? Dados.carregarGeo(`output/geo/ufs_${entrada.uf}.topojson`) : Promise.resolve(null),
    ]);

    estadoAtual = { topo, resultado, unidade: entrada.unidade, cargo: entrada.cargo, uf: entrada.uf, topoContornoUf };
    Seletores.popularCandidatos(resultado);
    Seletores.atualizarDisponibilidadeLisa(entrada.lisa_disponivel);
    Seletores.atualizarVisibilidadeCandidato(selModo.value);
    renderizarComEstadoAtual();
    status.textContent = "";
  }

  // Trocar Cargo/Turno não deve resetar a UF pro primeiro valor da lista
  // (Acre) — `Seletores.popularUfs`/`popularTurnos`/`popularUnidades` já
  // preservam a seleção atual quando ela continua válida pro novo
  // contexto (ver `preencher()` em seletores.js); só o carregamento
  // inicial abaixo força um valor explícito.
  selCargo.addEventListener("change", () => {
    Seletores.popularUfs(Dados.entradas(), selCargo.value);
    selUf.dispatchEvent(new Event("change"));
  });

  selUf.addEventListener("change", () => {
    Seletores.popularTurnos(Dados.entradas(), selCargo.value, selUf.value);
    selTurno.dispatchEvent(new Event("change"));
  });

  selTurno.addEventListener("change", () => {
    Seletores.popularUnidades(Dados.entradas(), selCargo.value, selUf.value, Number(selTurno.value));
    selUnidade.dispatchEvent(new Event("change"));
  });

  selUnidade.addEventListener("change", carregarDadosDaSelecao);

  selModo.addEventListener("change", () => {
    Seletores.atualizarVisibilidadeCandidato(selModo.value);
    renderizarComEstadoAtual();
  });

  selCandidato.addEventListener("change", renderizarComEstadoAtual);

  // O mapa se redesenha sozinho ao trocar de tema (Mapa.definirTema); a
  // legenda do LISA também depende do tema, então só ela é refeita aqui.
  document.addEventListener("tema-alterado", () => {
    if (!estadoAtual.resultado) return;
    Seletores.renderizarLegenda({
      modo: selModo.value,
      resultado: estadoAtual.resultado,
      sqCandidato: selCandidato.value,
      porPartido: legendaPorPartido(),
    });
  });

  Mapa.iniciar();
  Tema.iniciar();

  // O painel flutua sobre o mapa Leaflet — sem isso, clicar/rolar dentro
  // dele também arrasta/dá zoom no mapa por baixo.
  const painel = document.getElementById("controles");
  L.DomEvent.disableClickPropagation(painel);
  L.DomEvent.disableScrollPropagation(painel);

  status.textContent = "Carregando índice...";
  await Dados.carregarIndice();

  // Estado inicial (Presidente/Brasil) montado direto, sem passar pela
  // cascata de eventos acima — ela existe pra preservar a seleção do
  // usuário em trocas seguintes, mas aqui é a primeira carga, então o
  // padrão é forçado explicitamente em vez de cair na 1ª opção em ordem
  // alfabética (Acre/Governador).
  const entradasIniciais = Dados.entradas();
  Seletores.popularCargos(entradasIniciais, "Presidente");
  Seletores.popularUfs(entradasIniciais, selCargo.value, "BR");
  Seletores.popularTurnos(entradasIniciais, selCargo.value, selUf.value);
  Seletores.popularUnidades(entradasIniciais, selCargo.value, selUf.value, Number(selTurno.value));
  await carregarDadosDaSelecao();
})();
