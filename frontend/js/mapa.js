// Renderização do mapa Leaflet: troca a layer GeoJSON ativa conforme a
// seleção, sem recarregar a página.
const PROPRIEDADE_POR_UNIDADE = {
  municipio: "code_muni",
  microrregiao: "code_micro",
  mesorregiao: "code_meso",
  uf: "abbrev_state",
};

const TILES = {
  // CartoDB Dark Matter (basemaps.cartocdn.com) passou a exigir API key
  // (chave gratuita, mas com cadastro) e as tiles sem chave hoje só
  // devolvem um aviso "API KEY REQUIRED" em vez do mapa. Trocado pelo
  // Esri World Dark Gray Base, que não exige chave nem cadastro.
  escuro: {
    url: "https://services.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Dark_Gray_Base/MapServer/tile/{z}/{y}/{x}",
    attribution: "© Esri, HERE, Garmin, © OpenStreetMap contributors, GIS User Community",
  },
  claro: {
    url: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
    attribution: "© OpenStreetMap",
  },
};

const Mapa = (() => {
  let mapa = null;
  let layerAtiva = null;
  let layerContornoUf = null;
  let camadaTiles = null;
  let temaAtual = "escuro";
  let unidadeAtiva = null;
  let ultimoRender = null;

  // Linha mais fina quanto mais zoom out (menos zoom) — pra não virar
  // uma mancha de contorno quando os 5.570 municípios do Brasil cabem
  // inteiros na tela — e mais grossa conforme aproxima. UF bem mais
  // grossa que município/micro/meso, pra marcar a fronteira estadual
  // com destaque, mas ainda com teto pra não virar um traço exagerado
  // nos zooms mais próximos.
  function pesoLinha(unidade, zoom) {
    const base = Math.max(0.15, Math.min(0.7, 0.15 + (zoom - 4) * 0.08));
    return unidade === "uf" ? Math.min(base * 3.15, 1.98) : base;
  }

  function atualizarPesoLinha() {
    if (layerAtiva && unidadeAtiva) {
      layerAtiva.setStyle({ weight: pesoLinha(unidadeAtiva, mapa.getZoom()) });
    }
    if (layerContornoUf) {
      layerContornoUf.setStyle({ weight: pesoLinha("uf", mapa.getZoom()) });
    }
  }

  function iniciar() {
    mapa = L.map("map", { zoomControl: false }).setView([-8.3, -37.5], 7); // centro aproximado de PE
    L.control.zoom({ position: "bottomright" }).addTo(mapa);
    mapa.on("zoomend", atualizarPesoLinha);
    return mapa;
  }

  function definirTema(tema) {
    temaAtual = tema;
    const config = TILES[tema] || TILES.escuro;
    if (camadaTiles) {
      mapa.removeLayer(camadaTiles);
    }
    camadaTiles = L.tileLayer(config.url, { attribution: config.attribution, maxZoom: 18 }).addTo(mapa);

    // Estilos que dependem do tema (ex.: "Não significante" do LISA) são
    // calculados na hora de renderizar — sem redesenhar, a layer ativa
    // ficava com as cores do tema anterior. Sem re-enquadrar a vista.
    if (ultimoRender) {
      renderizar(ultimoRender, { ajustarVista: false });
    }
  }

  function estiloVencedor(feature, resultado, propId, unidade) {
    const id = String(feature.properties[propId]);
    const vencedor = resultado.vencedores[id];
    const peso = pesoLinha(unidade, mapa.getZoom());
    if (!vencedor) {
      return { fillColor: "#999999", fillOpacity: 0.6, color: "#ffffff", weight: peso };
    }
    const cor =
      vencedor.intensidade === "alta" ? Cores.escurecer(vencedor.cor, 0.25) : Cores.interpolarComBranco(vencedor.cor, 0.55);
    return { fillColor: cor, fillOpacity: 0.9, color: "#ffffff", weight: peso };
  }

  function estiloIsolado(feature, resultado, propId, unidade, sqCandidato) {
    const id = String(feature.properties[propId]);
    const candidato = resultado.candidatos[sqCandidato];
    const pct = candidato && candidato.valores[id] != null ? candidato.valores[id] : 0;
    return {
      fillColor: Cores.interpolarComBranco(candidato.cor, pct / 100),
      fillOpacity: 0.9,
      color: "#ffffff",
      weight: pesoLinha(unidade, mapa.getZoom()),
    };
  }

  function estiloLisa(feature, resultado, propId, unidade, sqCandidato) {
    const id = String(feature.properties[propId]);
    const candidato = resultado.candidatos[sqCandidato];
    const cluster = candidato && candidato.lisa ? candidato.lisa[id] : null;
    return {
      fillColor: Cores.corLisa(cluster, temaAtual),
      fillOpacity: Cores.opacidadeLisa(cluster, temaAtual),
      color: "#ffffff",
      weight: pesoLinha(unidade, mapa.getZoom()),
    };
  }

  function popupTexto(feature, resultado, propId, unidade, modo, sqCandidato) {
    const id = String(feature.properties[propId]);
    const nomeUnidade =
      feature.properties.name_muni ||
      feature.properties.name_micro ||
      feature.properties.name_meso ||
      feature.properties.name_state ||
      id;

    if (modo === "vencedor") {
      const v = resultado.vencedores[id];
      if (!v) return nomeUnidade;
      return `<b>${nomeUnidade}</b><br>${v.nome} (${v.partido})<br>${v.pct.toFixed(1)}% — margem de ${v.margem.toFixed(1)} p.p. (${v.intensidade})`;
    }

    const candidato = resultado.candidatos[sqCandidato];
    const pct = candidato && candidato.valores[id] != null ? candidato.valores[id] : null;
    const linhaPct = pct != null ? `${pct.toFixed(1)}%` : "sem dados";

    if (modo === "lisa") {
      const cluster = candidato && candidato.lisa ? candidato.lisa[id] : "sem dados";
      return `<b>${nomeUnidade}</b><br>${candidato.nome}: ${linhaPct}<br>Cluster: ${cluster}`;
    }

    return `<b>${nomeUnidade}</b><br>${candidato.nome}: ${linhaPct}`;
  }

  // `topoContornoUf`: TopoJSON de UF (`ufs_{uf}.topojson`) desenhado por
  // cima da unidade ativa, só contorno (sem preenchimento, sem popup/
  // clique) — pra marcar a fronteira estadual mesmo quando a unidade
  // selecionada é município/micro/meso. `null` quando a própria unidade
  // já é "uf" (o contorno seria idêntico à layer principal).
  function renderizarContornoUf(topoContornoUf) {
    if (layerContornoUf) {
      mapa.removeLayer(layerContornoUf);
      layerContornoUf = null;
    }
    if (!topoContornoUf) return;

    const geojson = topojson.feature(topoContornoUf, topoContornoUf.objects.geometrias);
    layerContornoUf = L.geoJSON(geojson, {
      interactive: false,
      style: () => ({
        fill: false,
        color: "#ffffff",
        weight: pesoLinha("uf", mapa.getZoom()),
      }),
    }).addTo(mapa);
    layerContornoUf.bringToFront();
  }

  function renderizar(args, { ajustarVista = true } = {}) {
    const { topo, resultado, unidade, modo, sqCandidato, topoContornoUf } = args;
    ultimoRender = args;
    const propId = PROPRIEDADE_POR_UNIDADE[unidade];
    const geojson = topojson.feature(topo, topo.objects.geometrias);
    unidadeAtiva = unidade;

    if (layerAtiva) {
      mapa.removeLayer(layerAtiva);
    }

    layerAtiva = L.geoJSON(geojson, {
      style: (feature) => {
        if (modo === "vencedor") return estiloVencedor(feature, resultado, propId, unidade);
        if (modo === "lisa") return estiloLisa(feature, resultado, propId, unidade, sqCandidato);
        return estiloIsolado(feature, resultado, propId, unidade, sqCandidato);
      },
      onEachFeature: (feature, layer) => {
        layer.bindPopup(popupTexto(feature, resultado, propId, unidade, modo, sqCandidato));
      },
    }).addTo(mapa);

    renderizarContornoUf(unidade === "uf" ? null : topoContornoUf);

    if (ajustarVista) {
      const limites = layerAtiva.getBounds();
      if (limites.isValid()) {
        mapa.fitBounds(limites, { padding: [10, 10] });
      }
    }
  }

  return { iniciar, renderizar, definirTema };
})();
