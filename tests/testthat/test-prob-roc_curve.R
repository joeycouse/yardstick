test_that("binary roc curve uses equivalent of pROC `direction = <`", {
  # In yardstick we do events (or cases) as the first level
  truth <- factor(c("control", "case", "case"), levels = c("case", "control"))

  # Make really bad predictions
  # This would force `direction = "auto"` to choose `>`,
  # which would be incorrect. We are required to force `direction = <` for
  # our purposes of having `estimate` match the event
  estimate <- c(.8, .2, .1)

  # # pROC expects levels to be in the order of control, then event.
  # roc <- pROC::roc(
  #   truth,
  #   estimate,
  #   levels = c("control", "case"),
  #   direction = "<"
  # )
  # expect_specificity <- c(0, roc$specificities)
  # expect_sensitivity <- c(1, roc$sensitivities)
  expect_specificity <- c(0, 0, 0, 0, 1)
  expect_sensitivity <- c(1, 1, 0.5, 0, 0)

  curve <- roc_curve_vec(truth, estimate)

  expect_identical(curve$specificity, expect_specificity)
  expect_identical(curve$sensitivity, expect_sensitivity)
})

test_that('ROC Curve', {
  pROC_two_class_example_curve <- data_pROC_two_class_example_curve()

  # Equal to pROC up to a reasonable tolerance
  expect_equal(
    roc_curve(two_class_example, truth, Class1),
    pROC_two_class_example_curve
  )
})

test_that("Multiclass ROC Curve", {
  # HPC_CV takes too long
  hpc_cv2 <- dplyr::filter(hpc_cv, Resample %in% c("Fold06", "Fold07", "Fold08", "Fold09", "Fold10"))

  res <- roc_curve(hpc_cv2, obs, VF:L)

  # structural tests
  expect_equal(colnames(res), c(".level", ".threshold", "specificity", "sensitivity"))
  expect_equal(unique(res$.level), levels(hpc_cv2$obs))

  res_g <- roc_curve(dplyr::group_by(hpc_cv2, Resample), obs, VF:L)

  # structural tests
  expect_equal(colnames(res_g), c("Resample", ".level", ".threshold", "specificity", "sensitivity"))
})

# ------------------------------------------------------------------------------

test_that("grouped multiclass (one-vs-all) weighted example matches expanded equivalent", {
  hpc_cv$weight <- rep(1, times = nrow(hpc_cv))
  hpc_cv$weight[c(100, 200, 150, 2)] <- 5

  hpc_cv <- dplyr::group_by(hpc_cv, Resample)

  hpc_cv_expanded <- hpc_cv[vec_rep_each(seq_len(nrow(hpc_cv)), times = hpc_cv$weight),]

  expect_identical(
    roc_curve(hpc_cv, obs, VF:L, case_weights = weight),
    roc_curve(hpc_cv_expanded, obs, VF:L)
  )
})

test_that("can use hardhat case weights", {
  two_class_example$weight <- read_weights_two_class_example()
  curve1 <- roc_curve(two_class_example, truth, Class1, case_weights = weight)

  two_class_example$weight <- hardhat::importance_weights(two_class_example$weight)
  curve2 <- roc_curve(two_class_example, truth, Class1, case_weights = weight)

  expect_identical(curve1, curve2)
})

# ------------------------------------------------------------------------------

test_that("zero weights don't affect the curve", {
  # If they weren't removed, we'd get a `NaN` from a division by zero issue
  df <- dplyr::tibble(
    truth = factor(c("b", "a", "b", "a", "a"), levels = c("a", "b")),
    a = c(.75, .7, .4, .9, .8),
    weight = c(0, 1, 3, 0, 5)
  )

  expect_identical(
    roc_curve(df, truth, a, case_weights = weight),
    roc_curve(df[df$weight != 0,], truth, a, case_weights = weight)
  )
})

# ------------------------------------------------------------------------------

test_that("Binary results are the same as scikit-learn", {
  curve <- roc_curve(two_class_example, truth, Class1)

  expect_identical(
    curve,
    read_pydata("py-roc-curve")$binary
  )
})

test_that("Binary weighted results are the same as scikit-learn", {
  two_class_example$weight <- read_weights_two_class_example()

  curve <- roc_curve(two_class_example, truth, Class1, case_weights = weight)

  expect_identical(
    curve,
    read_pydata("py-roc-curve")$case_weight$binary
  )
})

# ------------------------------------------------------------------------------

test_that("roc_curve() - error is thrown when missing events", {
  no_event <- dplyr::filter(two_class_example, truth == "Class2")

  expect_error(
    roc_curve_vec(no_event$truth, no_event$Class1)[[".estimate"]],
    "No event observations were detected in `truth` with event level 'Class1'.",
    class = "yardstick_error_roc_truth_no_event"
  )
})

test_that("roc_curve() - error is thrown when missing controls", {
  no_control <- dplyr::filter(two_class_example, truth == "Class1")

  expect_error(
    roc_curve_vec(no_control$truth, no_control$Class1)[[".estimate"]],
    "No control observations were detected in `truth` with control level 'Class2'.",
    class = "yardstick_error_roc_truth_no_control"
  )
})

test_that("roc_curve() - multiclass one-vs-all approach results in error", {
  no_event <- dplyr::filter(hpc_cv, Resample == "Fold01", obs == "VF")

  expect_error(
    roc_curve_vec(no_event$obs, as.matrix(dplyr::select(no_event, VF:L)))[[".estimate"]],
    "No control observations were detected in `truth` with control level '..other'",
    class = "yardstick_error_roc_truth_no_control"
  )
})

test_that("roc_curve() - `options` is deprecated", {
  skip_if(getRversion() <= "3.5.3", "Base R used a different deprecated warning class.")
  local_lifecycle_warnings()

  expect_snapshot({
    out <- roc_curve(two_class_example, truth, Class1, options = 1)
  })

  expect_identical(
    out,
    roc_curve(two_class_example, truth, Class1)
  )
})
