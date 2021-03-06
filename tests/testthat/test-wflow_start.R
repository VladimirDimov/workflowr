context("wflow_start")

# Inspired by rmarkdown tests of render_site
# https://github.com/rstudio/rmarkdown/blob/b95340817f3b285d38be4ba4ceb0a1d280de65f4/tests/testthat/test-site.R

# Setup ------------------------------------------------------------------------

library("git2r")

infrastructure_path <- system.file("infrastructure/",
                                   package = "workflowr")
project_files <- list.files(path = infrastructure_path, all.files = TRUE,
                            recursive = TRUE)
# Remove Rproj file since that is dynamically renamed
project_files <- project_files[!grepl("Rproj", project_files)]
# Add .Rprofile
project_files <- c(project_files, ".Rprofile")

git_files <- c(".git", ".gitignore")

# Test wflow_start -------------------------------------------------------------

test_that("wflow_start copies files correctly", {

  # start project in a tempdir
  site_dir <- workflowr:::tempfile(tmpdir = workflowr:::normalizePath("/tmp"))
  capture.output(wflow_start(site_dir, change_wd = FALSE))

  for (f in c(project_files, git_files)) {
    expect_true(file.exists(file.path(site_dir, f)))
  }
  expect_true(file.exists(file.path(site_dir,
                                    paste0(basename(site_dir), ".Rproj"))))
  unlink(site_dir, recursive = TRUE, force = TRUE)
})

test_that("wflow_start adds name to analysis/_site.yml and README.md", {

  site_dir <- workflowr:::tempfile(tmpdir = workflowr:::normalizePath("/tmp"))
  capture.output(wflow_start(site_dir, change_wd = FALSE))

  readme_contents <- readLines(file.path(site_dir, "README.md"))
  expect_identical(readme_contents[1], paste("#", basename(site_dir)))

  site_yaml_contents <- readLines(file.path(site_dir, "analysis", "_site.yml"))
  expect_identical(site_yaml_contents[1], paste("name:", basename(site_dir)))

  unlink(site_dir, recursive = TRUE, force = TRUE)
})

test_that("wflow_start accepts custom name", {

  project_name <- "A new project"
  site_dir <- workflowr:::tempfile(tmpdir = workflowr:::normalizePath("/tmp"))
  capture.output(wflow_start(site_dir, name = project_name, change_wd = FALSE))

  readme_contents <- readLines(file.path(site_dir, "README.md"))
  expect_identical(readme_contents[1], paste("#", project_name))

  site_yaml_contents <- readLines(file.path(site_dir, "analysis", "_site.yml"))
  expect_identical(site_yaml_contents[1], paste("name:", project_name))

  unlink(site_dir, recursive = TRUE, force = TRUE)
})

test_that("wflow_start creates docs/ directories and .nojekyll files", {

  # start project in a tempdir
  site_dir <- workflowr:::tempfile(tmpdir = workflowr:::normalizePath("/tmp"))
  capture.output(wflow_start(site_dir, change_wd = FALSE))

  expect_true(dir.exists(file.path(site_dir, "docs")))
  expect_true(file.exists(file.path(site_dir, "docs", ".nojekyll")))
  expect_true(file.exists(file.path(site_dir, "analysis", ".nojekyll")))

  unlink(site_dir, recursive = TRUE, force = TRUE)
})

test_that("wflow_start creates Git infrastructure by default", {

  # start project in a tempdir
  site_dir <- workflowr:::tempfile(tmpdir = workflowr:::normalizePath("/tmp"))
  capture.output(wflow_start(site_dir, change_wd = FALSE))
  for (f in git_files) {
    expect_true(file.exists(file.path(site_dir, f)))
  }
  unlink(site_dir, recursive = TRUE, force = TRUE)
})

test_that("wflow_start git = FALSE removes only the Git files", {

  # start project in a tempdir
  site_dir <- workflowr:::tempfile(tmpdir = workflowr:::normalizePath("/tmp"))
  capture.output(wflow_start(site_dir,
                             git = FALSE, change_wd = FALSE))

  for (f in project_files) {
    expect_true(file.exists(file.path(site_dir, f)))
  }
  expect_true(file.exists(file.path(site_dir,
                                    paste0(basename(site_dir), ".Rproj"))))
  # Git files do not exist
  for (f in git_files) {
    expect_false(file.exists(file.path(site_dir, f)))
  }
  unlink(site_dir, recursive = TRUE, force = TRUE)
})

test_that("wflow_start commits all the project files", {

  # start project in a tempdir
  site_dir <- workflowr:::tempfile(tmpdir = workflowr:::normalizePath("/tmp"))
  capture.output(wflow_start(site_dir, change_wd = FALSE))

  r <- git2r::repository(site_dir)
  committed <- workflowr:::get_committed_files(r)

  for (f in project_files) {
    expect_true(f %in% committed)
  }
  # Rproj file
  expect_true(paste0(basename(site_dir), ".Rproj") %in% committed)
  # hidden files
  expect_true(".gitignore" %in% committed)
  expect_true("analysis/.nojekyll" %in% committed)
  expect_true("docs/.nojekyll" %in% committed)

  unlink(site_dir, recursive = TRUE, force = TRUE)
})

test_that("wflow_start does not overwrite files by default", {

  # start project in a tempdir
  site_dir <- workflowr:::tempfile(tmpdir = workflowr:::normalizePath("/tmp"))
  dir.create(site_dir)
  readme_file <- file.path(site_dir, "README.md")
  writeLines("original", con = readme_file)
  rprofile_file <- file.path(site_dir, ".Rprofile")
  writeLines("x <- 1", con = rprofile_file)
  expect_warning(wflow_start(site_dir, existing = TRUE,
                             change_wd = FALSE),
                 "Set overwrite = TRUE to replace")

  readme_contents <- readLines(readme_file)
  expect_true(readme_contents == "original")
  rprofile_contents <- readLines(rprofile_file)
  expect_true(rprofile_contents == "x <- 1")
  unlink(site_dir, recursive = TRUE, force = TRUE)
})

test_that("wflow_start overwrites files when forced", {

  # start project in a tempdir
  site_dir <- workflowr:::tempfile(tmpdir = workflowr:::normalizePath("/tmp"))
  dir.create(site_dir)
  readme_file <- file.path(site_dir, "README.md")
  writeLines("original", con = readme_file)
  rprofile_file <- file.path(site_dir, ".Rprofile")
  writeLines("x <- 1", con = rprofile_file)
  capture.output(wflow_start(site_dir,
                             existing = TRUE, overwrite = TRUE,
                             change_wd = FALSE))

  readme_contents <- readLines(readme_file)
  expect_true(readme_contents[1] == sprintf("# %s", basename(site_dir)))
  rprofile_contents <- readLines(rprofile_file)
  expect_false(any(rprofile_contents == "x <- 1"))
  unlink(site_dir, recursive = TRUE, force = TRUE)
})

test_that("wflow_start does not overwrite an existing .git directory and does not commit existing files", {

  # start project in a tempdir
  site_dir <- workflowr:::tempfile(tmpdir = workflowr:::normalizePath("/tmp"))
  dir.create(site_dir)
  git2r::init(site_dir)
  r <- git2r::repository(site_dir)
  fake_file <- file.path(site_dir, "file.txt")
  file.create(fake_file)
  git2r::add(r, fake_file)
  git2r::commit(r, message = "The first commit")
  fake_untracked <- file.path(site_dir, "untracked.txt")
  expect_warning(wflow_start(site_dir, existing = TRUE,
                             change_wd = FALSE),
                 "A .git directory already exists in")
  log <- git2r::commits(r)
  expect_true(length(log) == 2)
  expect_false(fake_untracked %in%
                 workflowr:::obtain_files_in_commit(r, log[[1]]))
  unlink(site_dir, recursive = TRUE, force = TRUE)
})

test_that("wflow_start throws an error if user.name and user.email are not set", {
  config_original <- "~/.gitconfig"
  if (file.exists(config_original)) {
    config_tmp <- "~/.gitconfig-workflowr"
    file.rename(from = config_original, to = config_tmp)
    on.exit(file.rename(from = config_tmp, to = config_original))
  }
  site_dir <- workflowr:::tempfile(tmpdir = workflowr:::normalizePath("/tmp"))
  expect_error(wflow_start(site_dir, change_wd = FALSE),
               "You must set your user.name and user.email for Git first\n")
  expect_false(dir.exists(site_dir))
})

test_that("wflow_start can handle relative path to current directory: .", {

  # start project in a tempdir
  site_dir <- workflowr:::tempfile("test-start-", tmpdir = workflowr:::normalizePath("/tmp"))
  dir.create(site_dir)
  cwd <- getwd()
  setwd(site_dir)
  on.exit(setwd(cwd))
  on.exit(unlink(site_dir, recursive = TRUE, force = TRUE), add = TRUE)

  capture.output(wflow_start(".", existing = TRUE, change_wd = FALSE))

  expect_true(file.exists(paste0(basename(site_dir), ".Rproj")))
})

test_that("wflow_start can handle relative path to upstream directory: ..", {

  # start project in a tempdir
  site_dir <- workflowr:::tempfile("test-start-", tmpdir = workflowr:::normalizePath("/tmp"))
  site_dir_subdir <- file.path(site_dir, "random-subdir")
  dir.create(site_dir_subdir, recursive = TRUE)
  cwd <- getwd()
  setwd(site_dir_subdir)
  on.exit(setwd(cwd))
  on.exit(unlink(site_dir, recursive = TRUE, force = TRUE), add = TRUE)

  capture.output(wflow_start("..", existing = TRUE, change_wd = FALSE))

  expect_true(file.exists(file.path("..", paste0(basename(site_dir), ".Rproj"))))
})

test_that("wflow_start can handle relative paths to non-existent directories", {

  # Create and move to a temp directory
  tmp_dir <- workflowr:::tempfile("test-start-relative-", tmpdir = workflowr:::normalizePath("/tmp"))
  dir.create(tmp_dir)
  cwd <- getwd()
  setwd(tmp_dir)
  on.exit(setwd(cwd))
  on.exit(unlink(tmp_dir, recursive = TRUE, force = TRUE), add = TRUE)

  # Use the current working directory to set path to new directory, e.g. specify
  # "./new" instead of "new". There is no advantage to this more verbose option,
  # but it shouldn't break the code.
  capture.output(wflow_start("./new", change_wd = FALSE))
  expect_true(file.exists("./new/new.Rproj"))

  # Create and move to an unrelated subdirectory
  dir.create("unrelated")
  setwd("unrelated")

  # Start a new workflowr project in an upstream, non-existent directory
  capture.output(wflow_start("../upstream", change_wd = FALSE))
  expect_true(file.exists("../upstream/upstream.Rproj"))
})


test_that("wflow_start can handle deeply nested paths that need to be created", {

  # Create and move to a temp directory
  tmp_dir <- workflowr:::tempfile("test-deeply-nested-", tmpdir = workflowr:::normalizePath("/tmp"))
  dir.create(tmp_dir)
  cwd <- getwd()
  setwd(tmp_dir)
  on.exit(setwd(cwd))
  on.exit(unlink(tmp_dir, recursive = TRUE, force = TRUE), add = TRUE)

  dir_test <- "a/b/c/x/y/z"
  expected <- file.path(workflowr:::normalizePath("."), dir_test)
  capture.output(actual <- wflow_start(dir_test, change_wd = FALSE))
  expect_identical(actual, expected)
  expect_true(file.exists(file.path(expected, "z.Rproj")))
})

test_that("wflow_start can handle deeply nested paths that need to be created and begin with ./", {

  # Create and move to a temp directory
  tmp_dir <- workflowr:::tempfile("test-deeply-nested-plus-cwd-", tmpdir = workflowr:::normalizePath("/tmp"))
  dir.create(tmp_dir)
  cwd <- getwd()
  setwd(tmp_dir)
  on.exit(setwd(cwd))
  on.exit(unlink(tmp_dir, recursive = TRUE, force = TRUE), add = TRUE)

  dir_test <- "./a/b/c/x/y/z"
  expected <- file.path(workflowr:::normalizePath("."),
                        substr(dir_test, 3, nchar(dir_test)))
  capture.output(actual <- wflow_start(dir_test, change_wd = FALSE))
  expect_identical(actual, expected)
  expect_true(file.exists(file.path(expected, "z.Rproj")))
})

test_that("wflow_start can handle deeply nested paths that need to be created and use relative paths", {

  # Create and move to a temp directory
  tmp_dir <- workflowr:::tempfile("test-deeply-nested-plus-relative-", tmpdir = workflowr:::normalizePath("/tmp"))
  dir.create(tmp_dir)
  cwd <- getwd()
  setwd(tmp_dir)
  on.exit(setwd(cwd))
  on.exit(unlink(tmp_dir, recursive = TRUE, force = TRUE), add = TRUE)

  # Create and move to a nested directory
  dir_unrelated <- "1/2/3/4/5/6"
  dir.create(dir_unrelated, recursive = TRUE)
  setwd(dir_unrelated)

  # Start workflowr project in a highly nested upstream directory
  dir_test <- "../../../../../../a/b/c/x/y/z"
  expected <- file.path(tmp_dir, "a/b/c/x/y/z")
  capture.output(actual <- wflow_start(dir_test, change_wd = FALSE))
  expect_identical(actual, expected)
  expect_true(file.exists(file.path(expected, "z.Rproj")))
})

test_that("wflow_start throws error when given a deeply nested path that needs to be created, uses relative paths, and is contained within a Git repository", {

  # Create and move to a temp directory
  tmp_dir <- workflowr:::tempfile("test-deeply-nested-plus-relative-git-", tmpdir = workflowr:::normalizePath("/tmp"))
  dir.create(tmp_dir)
  cwd <- getwd()
  setwd(tmp_dir)
  on.exit(setwd(cwd))
  on.exit(unlink(tmp_dir, recursive = TRUE, force = TRUE), add = TRUE)

  # Make this base directory a Git repository
  git2r::init(".")

  # Create and move to a nested directory
  dir_unrelated <- "1/2/3/4/5/6"
  dir.create(dir_unrelated, recursive = TRUE)
  setwd(dir_unrelated)

  # Start workflowr project in a highly nested upstream directory
  dir_test <- "../../../../../../a/b/c/x/y/z"
  # Should throw error and not create directory
  expect_error(wflow_start(dir_test, change_wd = FALSE),
               tmp_dir)
  expect_false(dir.exists(file.path(tmp_dir, "a/b/c/x/y/z")))
})

test_that("wflow_start changes to workflowr directory by default", {

  # start project in a tempdir
  site_dir <- workflowr:::tempfile("test-start-", tmpdir = workflowr:::normalizePath("/tmp"))
  cwd <- getwd()
  on.exit(setwd(cwd))
  on.exit(unlink(site_dir, recursive = TRUE, force = TRUE), add = TRUE)

  capture.output(wflow_start(site_dir))

  expect_identical(getwd(), site_dir)
})

test_that("wflow_start fails early if directory exists and `existing = FALSE`", {

  site_dir <- workflowr:::tempfile("test-start-", tmpdir = workflowr:::normalizePath("/tmp"))
  dir.create(site_dir)
  on.exit(unlink(site_dir, recursive = TRUE, force = TRUE))

  expect_error(wflow_start(site_dir, change_wd = FALSE),
               "Directory already exists. Set existing = TRUE if you wish to add workflowr files to an already existing project.")

})

test_that("wflow_start fails early if directory does not exist and `existing = TRUE`", {

  site_dir <- workflowr:::tempfile("test-start-", tmpdir = workflowr:::normalizePath("/tmp"))

  expect_error(wflow_start(site_dir, existing = TRUE, change_wd = FALSE),
               "Directory does not exist. Set existing = FALSE to create a new directory for the workflowr files.")
  expect_false(dir.exists(site_dir))

})
