source(testthat::test_path("..", "..", "R", "01_aquisicao.R"))
source(testthat::test_path("..", "..", "R", "02_leitura.R"))
source(testthat::test_path("..", "..", "R", "03_limpeza.R"))
source(testthat::test_path("..", "..", "R", "04_crosswalk.R"))
source(testthat::test_path("..", "..", "R", "05_geo_join.R"))
source(testthat::test_path("..", "..", "R", "07_vencedores.R"))

dir_downloads <- testthat::test_path("..", "..", "data-raw", "downloads")
dir_interim <- testthat::test_path("..", "..", "data", "interim")
zip_2022 <- file.path(dir_downloads, "2022", "votacao_candidato_munzona", "votacao_candidato_munzona_2022.zip")
linkador <- testthat::test_path("..", "..", "data-raw", "ref", "linkador_bases.xlsx")

testthat::test_that("vencedor por UF bate com o resultado nacional (governador PE 2022, 2o turno)", {
  testthat::skip_if_not(file.exists(zip_2022), "ZIP de 2022 não encontrado")
  testthat::skip_if_not(file.exists(linkador), "linkador_bases.xlsx não encontrado")
  testthat::skip_if_offline()

  info <- obter_dados_tse(2022, "PE", base_dir = dir_downloads)
  dados <- ler_votacao_munzona(info$zip, info$membro, dir_cache = dir_interim)
  limpo <- limpar_votacao(dados)
  juntado <- juntar_ibge(limpo, carregar_crosswalk_tse_ibge(linkador))

  municipios_sf <- obter_municipios_sf("PE")
  cw_meso_micro <- derivar_crosswalk_meso_micro(municipios_sf, obter_meso_sf("PE"), obter_micro_sf("PE"))

  gov2 <- juntado[juntado$DS_CARGO == "Governador" & juntado$NR_TURNO == 2, ]

  vencedor_uf <- calcular_vencedor(agregar_por_unidade(gov2, cw_meso_micro, "uf"))
  testthat::expect_equal(vencedor_uf$NM_URNA_CANDIDATO, "RAQUEL LYRA")
  testthat::expect_equal(vencedor_uf$pct_validos, 58.70, tolerance = 0.05)

  vencedor_muni <- calcular_vencedor(agregar_por_unidade(gov2, cw_meso_micro, "municipio"))
  testthat::expect_equal(nrow(vencedor_muni), 185)
  testthat::expect_equal(sum(vencedor_muni$NM_URNA_CANDIDATO == "RAQUEL LYRA"), 105)

  vencedor_meso <- calcular_vencedor(agregar_por_unidade(gov2, cw_meso_micro, "mesorregiao"))
  testthat::expect_equal(nrow(vencedor_meso), 5)

  vencedor_micro <- calcular_vencedor(agregar_por_unidade(gov2, cw_meso_micro, "microrregiao"))
  testthat::expect_equal(nrow(vencedor_micro), 19)
})

testthat::test_that("agregar_por_unidade sempre soma pct_validos = 100 por unidade", {
  testthat::skip_if_not(file.exists(zip_2022), "ZIP de 2022 não encontrado")
  testthat::skip_if_not(file.exists(linkador), "linkador_bases.xlsx não encontrado")
  testthat::skip_if_offline()

  info <- obter_dados_tse(2022, "PE", base_dir = dir_downloads)
  dados <- ler_votacao_munzona(info$zip, info$membro, dir_cache = dir_interim)
  limpo <- limpar_votacao(dados)
  juntado <- juntar_ibge(limpo, carregar_crosswalk_tse_ibge(linkador))

  municipios_sf <- obter_municipios_sf("PE")
  cw_meso_micro <- derivar_crosswalk_meso_micro(municipios_sf, obter_meso_sf("PE"), obter_micro_sf("PE"))

  gov1 <- juntado[juntado$DS_CARGO == "Governador" & juntado$NR_TURNO == 1, ]

  for (unidade in c("municipio", "microrregiao", "mesorregiao", "uf")) {
    agregado <- agregar_por_unidade(gov1, cw_meso_micro, unidade)
    soma_pct <- tapply(agregado$pct_validos, agregado$unidade_id, sum)
    testthat::expect_true(all(abs(soma_pct - 100) < 1e-6), info = unidade)
  }
})
