// Renderização do mapa Leaflet: troca a layer GeoJSON ativa conforme a
// seleção, sem recarregar a página.
const PROPRIEDADE_POR_UNIDADE = {
  municipio: "code_muni",
  microrregiao: "code_micro",
  mesorregiao: "code_meso",
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
  let camadaTiles = null;

  function iniciar() {
    mapa = L.map("map", { zoomControl: false }).setView([-8.3, -37.5], 7); // centro aproximado de PE
    L.control.zoom({ position: "bottomright" }).addTo(mapa);
    return mapa;
  }

  function definirTema(tema) {
    const config = TILES[tema] || TILES.escuro;
    if (camadaTiles) {
      mapa.removeLayer(camadaTiles);
    }
    camadaTiles = L.tileLayer(config.url, { attribution: config.attribution, maxZoom: 18 }).addTo(mapa);
  }

  function estiloVencedor(feature, resultado, propId) {
    const id = String(feature.properties[propId]);
    const vencedor = resultado.vencedores[id];
    if (!vencedor) {
      return { fillColor: "#999999", fillOpacity: 0.6, color: "#ffffff", weight: 0.4 };
    }
    const cor =
      vencedor.intensidade === "alta" ? Cores.escurecer(vencedor.cor, 0.25) : Cores.interpolarComBranco(vencedor.cor, 0.55);
    return { fillColor: cor, fillOpacity: 0.9, color: "#ffffff", weight: 0.4 };
  }

  function estiloIsolado(feature, resultado, propId, sqCandidato) {
    const id = String(feature.properties[propId]);
    const candidato = resultado.candidatos[sqCandidato];
    const pct = candidato && candidato.valores[id] != null ? candidato.valores[id] : 0;
    return {
      fillColor: Cores.interpolarComBranco(candidato.cor, pct / 100),
      fillOpacity: 0.9,
      color: "#ffffff",
      weight: 0.4,
    };
  }

  function estiloLisa(feature, resultado, propId, sqCandidato) {
    const id = String(feature.properties[propId]);
    const candidato = resultado.candidatos[sqCandidato];
    const cluster = candidato && candidato.lisa ? candidato.lisa[id] : null;
    return {
      fillColor: Cores.corLisa(cluster),
      fillOpacity: 0.9,
      color: "#ffffff",
      weight: 0.4,
    };
  }

  function popupTexto(feature, resultado, propId, unidade, modo, sqCandidato) {
    const id = String(feature.properties[propId]);
    const nomeUnidade =
      feature.properties.name_muni || feature.properties.name_micro || feature.properties.name_meso || id;

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

  function renderizar({ topo, resultado, unidade, modo, sqCandidato }) {
    const propId = PROPRIEDADE_POR_UNIDADE[unidade];
    const geojson = topojson.feature(topo, topo.objects.geometrias);

    if (layerAtiva) {
      mapa.removeLayer(layerAtiva);
    }

    layerAtiva = L.geoJSON(geojson, {
      style: (feature) => {
        if (modo === "vencedor") return estiloVencedor(feature, resultado, propId);
        if (modo === "lisa") return estiloLisa(feature, resultado, propId, sqCandidato);
        return estiloIsolado(feature, resultado, propId, sqCandidato);
      },
      onEachFeature: (feature, layer) => {
        layer.bindPopup(popupTexto(feature, resultado, propId, unidade, modo, sqCandidato));
      },
    }).addTo(mapa);

    const limites = layerAtiva.getBounds();
    if (limites.isValid()) {
      mapa.fitBounds(limites, { padding: [10, 10] });
    }
  }

  return { iniciar, renderizar, definirTema };
})();
