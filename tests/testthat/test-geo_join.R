source(testthat::test_path("..", "..", "R", "05_geo_join.R"))

testthat::test_that("derivar_crosswalk_meso_micro casa 100% dos municípios de PE", {
  testthat::skip_if_offline()

  municipios_sf <- obter_municipios_sf("PE")
  meso_sf <- obter_meso_sf("PE")
  micro_sf <- obter_micro_sf("PE")

  cw <- derivar_crosswalk_meso_micro(municipios_sf, meso_sf, micro_sf)

  testthat::expect_equal(nrow(cw), 185)
  testthat::expect_equal(sum(is.na(cw$code_meso)), 0)
  testthat::expect_equal(sum(is.na(cw$code_micro)), 0)

  recife <- cw[municipios_sf$name_muni == "Recife", ]
  testthat::expect_equal(recife$name_meso, "Metropolitana de Recife")

  noronha <- cw[grepl("Fernando", municipios_sf$name_muni), ]
  testthat::expect_equal(noronha$name_micro, "Fernando de Noronha")
})
