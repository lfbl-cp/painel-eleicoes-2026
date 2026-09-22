# LISA (Local Indicators of Spatial Association) — só em nível de
# município. Microrregião/mesorregião/UF nunca entram aqui (ver CLAUDE.md).

#' Matriz de vizinhança por contiguidade (queen). Municípios sem vizinho
#' por contiguidade (ilhas de verdade, ex. Fernando de Noronha) recebem o
#' vizinho mais próximo por distância do centroide, adicionado nos dois
#' sentidos (senão o grafo fica assimétrico).
construir_vizinhanca <- function(municipios_sf) {
  nb <- spdep::poly2nb(municipios_sf, queen = TRUE)
  ilhas <- which(spdep::card(nb) == 0)

  if (length(ilhas) > 0) {
    coords <- sf::st_coordinates(sf::st_centroid(sf::st_geometry(municipios_sf)))
    vizinho_mais_proximo <- spdep::knn2nb(spdep::knearneigh(coords, k = 1))

    for (i in ilhas) {
      j <- as.integer(vizinho_mais_proximo[[i]][1])
      nb[[i]] <- j
      if (!(i %in% nb[[j]])) {
        nb[[j]] <- sort(c(nb[[j]][nb[[j]] != 0L], as.integer(i)))
      }
    }
  }

  spdep::nb2listw(nb, style = "W", zero.policy = TRUE)
}

#' LISA (Local Moran, base de permutação) para um vetor de valores (ex.:
#' `pct_validos` de um candidato, um valor por município, na mesma ordem
#' do `listw`).
#'
#' @param x Vetor numérico (ex.: % de votos válidos por município).
#' @param listw `spdep::listw` de `construir_vizinhanca()`.
#' @param alpha Limiar de significância (p >= alpha vira "Não significante").
#' @param nsim Número de permutações.
calcular_lisa <- function(x, listw, alpha = 0.05, nsim = 499) {
  resultado <- as.data.frame(spdep::localmoran_perm(x, listw, nsim = nsim, zero.policy = TRUE))

  defasagem <- spdep::lag.listw(listw, x, zero.policy = TRUE)
  media_x <- mean(x, na.rm = TRUE)
  media_defasagem <- mean(defasagem, na.rm = TRUE)
  p_valor <- resultado[["Pr(folded) Sim"]]

  cluster <- dplyr::case_when(
    p_valor >= alpha ~ "Não significante",
    x >= media_x & defasagem >= media_defasagem ~ "HH",
    x < media_x & defasagem < media_defasagem ~ "LL",
    x >= media_x & defasagem < media_defasagem ~ "HL",
    x < media_x & defasagem >= media_defasagem ~ "LH",
    TRUE ~ NA_character_
  )

  tibble::tibble(
    local_i = resultado[["Ii"]],
    p_valor = p_valor,
    defasagem_espacial = defasagem,
    cluster = cluster
  )
}
