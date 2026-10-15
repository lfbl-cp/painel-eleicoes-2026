// Camada de dados: carrega output/index.json uma vez e busca/cacheia
// topojson + resultado sob demanda. "BASE" assume que este arquivo é
// servido a partir de frontend/, com output/ como pasta irmã (na raiz do
// projeto) — ajustar se a hospedagem final mudar essa estrutura.
const BASE = "..";

const Dados = (() => {
  let indice = null;
  const cacheGeo = new Map();
  const cacheResultado = new Map();

  async function carregarIndice() {
    if (indice) return indice;
    const resp = await fetch(`${BASE}/output/index.json`);
    if (!resp.ok) throw new Error(`Falha ao carregar index.json: ${resp.status}`);
    indice = await resp.json();
    return indice;
  }

  function entradas() {
    if (!indice) throw new Error("Chame carregarIndice() antes de entradas().");
    return indice.entradas;
  }

  // Combinações do swing presidencial (lista `swing` do index.json, ver
  // `gerar_swing_presidente()` em pipeline/run_pipeline.R). Vazia se o
  // índice não tiver swing.
  function swing() {
    if (!indice) throw new Error("Chame carregarIndice() antes de swing().");
    return indice.swing || [];
  }

  async function carregarGeo(caminho) {
    if (cacheGeo.has(caminho)) return cacheGeo.get(caminho);
    const resp = await fetch(`${BASE}/${caminho}`);
    if (!resp.ok) throw new Error(`Falha ao carregar geometria ${caminho}: ${resp.status}`);
    const topo = await resp.json();
    cacheGeo.set(caminho, topo);
    return topo;
  }

  async function carregarResultado(caminho) {
    if (cacheResultado.has(caminho)) return cacheResultado.get(caminho);
    const resp = await fetch(`${BASE}/${caminho}`);
    if (!resp.ok) throw new Error(`Falha ao carregar resultado ${caminho}: ${resp.status}`);
    const json = await resp.json();
    cacheResultado.set(caminho, json);
    return json;
  }

  // Cards + rankings de um ano (output/candidatos/{ano}.json, ver
  // R/11_candidatos.R) -- carregado uma vez por ano. Cacheia a promessa pra
  // chamadas simultâneas (mapa e painel da direita) não baixarem duas vezes.
  const cacheCandidatos = new Map();
  function carregarCandidatos(ano) {
    if (!cacheCandidatos.has(ano)) {
      const p = fetch(`${BASE}/output/candidatos/${ano}.json`).then((resp) => {
        if (!resp.ok) throw new Error(`Falha ao carregar candidatos de ${ano}: ${resp.status}`);
        return resp.json();
      });
      p.catch(() => cacheCandidatos.delete(ano));
      cacheCandidatos.set(ano, p);
    }
    return cacheCandidatos.get(ano);
  }

  function urlFoto(ano, sq) {
    return `${BASE}/output/fotos/${ano}/${sq}.jpg`;
  }

  return { carregarIndice, entradas, swing, carregarGeo, carregarResultado, carregarCandidatos, urlFoto };
})();
