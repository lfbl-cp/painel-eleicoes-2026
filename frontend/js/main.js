// Orquestração: liga os seletores aos dados e ao mapa.
(async function main() {
  const selAno = document.getElementById("sel-ano");
  const selCargo = document.getElementById("sel-cargo");
  const selUf = document.getElementById("sel-uf");
  const selTurno = document.getElementById("sel-turno");
  const selUnidade = document.getElementById("sel-unidade");
  const selModo = document.getElementById("sel-modo");
  const selCandidato = document.getElementById("sel-candidato");
  const btnSwing = document.getElementById("btn-swing");
  const subtitulo = document.getElementById("subtitulo");
  const status = document.getElementById("status");

  let estadoAtual = { topo: null, resultado: null, unidade: null, cargo: null, uf: null, ano: null, turno: null, ids: [], topoContornoUf: null };

  // Swing (botão "Swing Lula × Flávio"): troca a fonte das entradas pela
  // lista `swing` do index.json e o modo do mapa por "swing". `chaveSwing`
  // é o candidato do par mostrado ("lula"/"flavio", ver R/10_swing.R).
  let modoSwing = false;
  let chaveSwing = "lula";

  // Entradas do contexto atual: as do swing, ou as da eleição selecionada.
  // A cascata Cargo → UF → Turno → Unidade abaixo funciona igual nos dois
  // casos (as entradas do swing também têm cargo/turno, só que fixos).
  function entradasAtivas() {
    if (modoSwing) return Dados.swing();
    return Dados.entradas().filter((e) => e.ano === Number(selAno.value));
  }

  function entradaSelecionada() {
    return entradasAtivas().find(
      (e) =>
        e.cargo === selCargo.value &&
        e.uf === selUf.value &&
        e.turno === Number(selTurno.value) &&
        e.unidade === selUnidade.value
    );
  }

  function modoAtual() {
    return modoSwing ? "swing" : selModo.value;
  }

  function candidatoAtual() {
    return modoSwing ? chaveSwing : selCandidato.value;
  }

  function atualizarSubtitulo(entrada) {
    subtitulo.textContent = modoSwing
      ? `Swing do 1º turno presidencial · ${entrada.ano_base} → ${entrada.ano}`
      : `Eleição ${selAno.value}`;
  }

  // Governador/Senador com UF = Brasil é um mosaico dos resultados de
  // cada UF (candidatos diferentes em cada uma) — nesse caso a legenda
  // agrupa por partido em vez de por candidato (ver seletores.js).
  function legendaPorPartido() {
    return (estadoAtual.cargo === "Governador" || estadoAtual.cargo === "Senador") && estadoAtual.uf === "BR";
  }

  function renderizarLegendaAtual() {
    Seletores.renderizarLegenda({
      modo: modoAtual(),
      resultado: estadoAtual.resultado,
      sqCandidato: candidatoAtual(),
      porPartido: legendaPorPartido(),
      idsUnidades: estadoAtual.ids,
    });
  }

  // Cor do partido de um candidato (pelo SQ), tirada do resultado do mapa;
  // no swing os candidatos são chaveados por "lula"/"flavio", com o SQ dentro.
  function corDe(sq) {
    const cands = Object.values(estadoAtual.resultado.candidatos);
    const c = modoSwing ? cands.find((x) => x.sq === sq) : estadoAtual.resultado.candidatos[sq];
    return (c && c.cor) || "#999999";
  }

  // Painel da direita: ranking no modo Vencedor, card do candidato nos demais.
  function atualizarPainelDireito() {
    const r = estadoAtual.resultado;
    PainelDireito.renderizar({
      ano: modoSwing ? r.ano : estadoAtual.ano,
      cargo: estadoAtual.cargo,
      turno: estadoAtual.turno,
      uf: estadoAtual.uf,
      modo: modoAtual(),
      sq: modoSwing ? r.candidatos[chaveSwing].sq : selCandidato.value,
      corDe,
      aoAbrir: abrirCandidato,
    });
  }

  // Clique num candidato do ranking: mapa contínuo dele. No mosaico nacional
  // de Governador/Senador, vai pra UF do candidato (cada UF tem a sua eleição).
  async function abrirCandidato(sq, ufCandidato) {
    if (estadoAtual.uf === "BR" && estadoAtual.cargo !== "Presidente" && ufCandidato && ufCandidato !== "BR") {
      selUf.value = ufCandidato;
      Seletores.popularTurnos(entradasAtivas(), selCargo.value, selUf.value);
      Seletores.popularUnidades(entradasAtivas(), selCargo.value, selUf.value, Number(selTurno.value));
      await carregarDadosDaSelecao();
    }
    if (!estadoAtual.resultado.candidatos[sq]) return;
    selModo.value = "isolado";
    selCandidato.value = sq;
    Seletores.atualizarVisibilidadeCandidato("isolado");
    renderizarComEstadoAtual();
  }

  function renderizarComEstadoAtual() {
    if (!estadoAtual.topo || !estadoAtual.resultado) return;
    Mapa.renderizar({
      topo: estadoAtual.topo,
      resultado: estadoAtual.resultado,
      unidade: estadoAtual.unidade,
      modo: modoAtual(),
      sqCandidato: candidatoAtual(),
      topoContornoUf: estadoAtual.topoContornoUf,
    });
    renderizarLegendaAtual();
    atualizarPainelDireito();
  }

  function escolherCandidatoSwing(chave) {
    chaveSwing = chave;
    Seletores.popularCandidatosSwing(estadoAtual.resultado, chaveSwing, escolherCandidatoSwing);
    // Mesmo arquivo e geometria, só muda a cor — sem re-enquadrar a vista.
    Mapa.renderizar(
      {
        topo: estadoAtual.topo,
        resultado: estadoAtual.resultado,
        unidade: estadoAtual.unidade,
        modo: "swing",
        sqCandidato: chaveSwing,
        topoContornoUf: estadoAtual.topoContornoUf,
      },
      { ajustarVista: false }
    );
    renderizarLegendaAtual();
    atualizarPainelDireito();
  }

  async function carregarDadosDaSelecao() {
    const entrada = entradaSelecionada();
    if (!entrada) {
      status.textContent = "Combinação sem dados exportados.";
      return;
    }

    status.textContent = "Carregando...";
    atualizarSubtitulo(entrada);
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

    const propId = PROPRIEDADE_POR_UNIDADE[entrada.unidade];
    const ids = topo.objects.geometrias.geometries.map((g) => String(g.properties[propId]));
    estadoAtual = {
      topo, resultado, unidade: entrada.unidade, cargo: entrada.cargo, uf: entrada.uf,
      ano: entrada.ano, turno: entrada.turno, ids, topoContornoUf,
    };
    if (modoSwing) {
      if (!resultado.candidatos[chaveSwing]) chaveSwing = Object.keys(resultado.candidatos)[0];
      Seletores.popularCandidatosSwing(resultado, chaveSwing, escolherCandidatoSwing);
    } else {
      Seletores.popularCandidatos(resultado, await PainelDireito.ordemCandidatos(entrada.ano, entrada.cargo, entrada.turno, entrada.uf));
      Seletores.atualizarDisponibilidadeLisa(entrada.lisa_disponivel);
      Seletores.atualizarVisibilidadeCandidato(selModo.value);
    }
    renderizarComEstadoAtual();
    status.textContent = "";
  }

  // Trocar Eleição/Cargo/Turno não deve resetar a UF pro primeiro valor da
  // lista (Acre) — `Seletores.popularUfs`/`popularTurnos`/`popularUnidades`
  // já preservam a seleção atual quando ela continua válida pro novo
  // contexto (ver `preencher()` em seletores.js); só o carregamento
  // inicial abaixo força um valor explícito.
  selAno.addEventListener("change", () => {
    Seletores.popularCargos(entradasAtivas());
    selCargo.dispatchEvent(new Event("change"));
  });

  selCargo.addEventListener("change", () => {
    Seletores.popularUfs(entradasAtivas(), selCargo.value);
    selUf.dispatchEvent(new Event("change"));
  });

  selUf.addEventListener("change", () => {
    Seletores.popularTurnos(entradasAtivas(), selCargo.value, selUf.value);
    selTurno.dispatchEvent(new Event("change"));
  });

  selTurno.addEventListener("change", () => {
    Seletores.popularUnidades(entradasAtivas(), selCargo.value, selUf.value, Number(selTurno.value));
    selUnidade.dispatchEvent(new Event("change"));
  });

  selUnidade.addEventListener("change", carregarDadosDaSelecao);

  selModo.addEventListener("change", () => {
    Seletores.atualizarVisibilidadeCandidato(selModo.value);
    renderizarComEstadoAtual();
  });

  selCandidato.addEventListener("change", renderizarComEstadoAtual);

  // Liga/desliga o swing. UF e Unidade são preservadas na troca (mesma
  // cascata dos seletores); ao sair, o mapa volta pra eleição selecionada.
  btnSwing.addEventListener("click", () => {
    modoSwing = !modoSwing;
    Seletores.atualizarVisibilidadeSwing(modoSwing);
    if (!modoSwing) Seletores.atualizarVisibilidadeCandidato(selModo.value);
    Seletores.popularCargos(entradasAtivas(), modoSwing ? "Presidente" : undefined);
    selCargo.dispatchEvent(new Event("change"));
  });

  // O mapa se redesenha sozinho ao trocar de tema (Mapa.definirTema); a
  // legenda do LISA também depende do tema, então só ela é refeita aqui.
  document.addEventListener("tema-alterado", () => {
    if (!estadoAtual.resultado) return;
    renderizarLegendaAtual();
  });

  Mapa.iniciar();
  Tema.iniciar();
  PainelDireito.iniciar();

  // O painel flutua sobre o mapa Leaflet — sem isso, clicar/rolar dentro
  // dele também arrasta/dá zoom no mapa por baixo.
  const painel = document.getElementById("controles");
  L.DomEvent.disableClickPropagation(painel);
  L.DomEvent.disableScrollPropagation(painel);

  status.textContent = "Carregando índice...";
  await Dados.carregarIndice();

  // Sem swing no índice (nenhuma rodada com ano base disponível), o botão
  // não tem o que mostrar.
  btnSwing.classList.toggle("oculto", Dados.swing().length === 0);

  // Estado inicial (eleição mais recente, Presidente/Brasil) montado
  // direto, sem passar pela cascata de eventos acima — ela existe pra
  // preservar a seleção do usuário em trocas seguintes, mas aqui é a
  // primeira carga, então o padrão é forçado explicitamente em vez de cair
  // na 1ª opção em ordem alfabética (Acre/Governador).
  Seletores.popularAnos(Dados.entradas());
  const entradasIniciais = entradasAtivas();
  Seletores.popularCargos(entradasIniciais, "Presidente");
  Seletores.popularUfs(entradasIniciais, selCargo.value, "BR");
  Seletores.popularTurnos(entradasIniciais, selCargo.value, selUf.value);
  Seletores.popularUnidades(entradasIniciais, selCargo.value, selUf.value, Number(selTurno.value));
  await carregarDadosDaSelecao();
})();
