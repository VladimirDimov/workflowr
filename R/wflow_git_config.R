#' Configure Git settings
#'
#' \code{wflow_git_config} configures the global Git settings on the current
#' machine. This is a convenience function to run Git commands from the R
#' console instead of the Terminal. The same functionality can be acheived by
#' running \code{git config} in the Terminal.
#'
#' The main purpose of \code{wflow_git_config} is to set the user.name and
#' user.email to use with Git commits (note that these do not need to match the
#' name and email you used to register your GitHub account). However, it can
#' also handle arbitrary Git settings (see examples below).
#'
#' There are two main limitations of \code{wflow_git_config} for the sake of
#' simplicity. First, \code{wflow_git_config} only affects the global Git
#' settings that apply to all Git repositories on the local machine and is
#' unable to configure settings for one specific Git repository. Second,
#' \code{wflow_git_config} can only add or change the user.name and user.email
#' settings, but not delete them. To perform either of these actions, please use
#' \code{git config} in the Terminal.
#'
#' Under the hood, \code{wflow_git_config} is a wrapper for
#' \code{\link[git2r]{config}} from the package \link{git2r}.
#'
#' To learn more about how to configure Git, see the Software Carpentry lesson
#' \href{http://swcarpentry.github.io/git-novice/02-setup/}{Setting Up Git}.
#'
#' @param user.name character (default: NULL). Git user name. Git assigns an
#'   author when committing (i.e. saving) changes. If you have never used Git
#'   before on your computer, make sure to set this.
#'
#' @param user.email character (default: NULL). Git user email. Git assigns an
#'   email when committing (i.e. saving) changes. If you have never used Git
#'   before on your computer, make sure to set this.
#'
#' @param ... Arbitrary Git settings, e.g. \code{core.editor = "nano"}.
#'
#' @return An object of class \code{wflow_git_config}, which is a list with the
#'   following elements:
#'
#' \itemize{
#'
#' \item \bold{user.name}: The current global Git user.name
#'
#' \item \bold{user.email}: The current global Git user.email
#'
#' \item \bold{all_settings}: A list of all current global Git settings
#'
#' }
#'
#' @examples
#' \dontrun{
#'
#' # View current Git settings
#' wflow_git_config()
#' # Set user.name and user.email
#' wflow_git_config(user.name = "A Name", user.email = "email@domain")
#' # Set core.editor (the text editor that Git opens to write commit messages)
#' wflow_git_config(core.editor = "nano")
#'
#' }
#'
#' @export
wflow_git_config <- function(user.name = NULL, user.email = NULL, ...) {

  # Check input arguments ------------------------------------------------------

  if (!(is.null(user.name) || (is.character(user.name) && length(user.name) == 1)))
    stop("user.name must be NULL or a one-element character vector")

  if (!(is.null(user.email) || (is.character(user.email) && length(user.email) == 1)))
    stop("user.email must be NULL or a one-element character vector")

  # Configure ------------------------------------------------------------------

  # user.name
  if (!is.null(user.name)) {
    git2r::config(global = TRUE, user.name = user.name)
  }

  # user.email
  if (!is.null(user.email)) {
    git2r::config(global = TRUE, user.email = user.email)
  }

  # Other settings
  other <- list(...)
  if (length(other) > 0) {
    git2r::config(global = TRUE, ...)
  }

  # Prepare output -------------------------------------------------------------

  git_config <- git2r::config(global = TRUE)
  o <- list(user.name = git_config$global$user.name,
            user.email = git_config$global$user.email,
            all_settings = git_config$global)
  class(o) <- "wflow_git_config"
  return(o)
}

#' @export
print.wflow_git_config <- function(x, ...) {

  if (is.null(x$user.name)) {
    cat("Current Git user.name needs to be configured\n")
  } else {
    cat(sprintf("Current Git user.name:\t%s\n", x$user.name))
  }

  if (is.null(x$user.email)) {
    cat("Current Git user.email needs to be configured\n")
  } else {
    cat(sprintf("Current Git user.email:\t%s\n", x$user.email))
  }

  other_settings <- x$all_settings
  other_settings[["user.name"]] <- NULL
  other_settings[["user.email"]] <- NULL
  settings_names <- names(other_settings)
  if (length(x) > 0) {
    cat("Other Git settings:\n")
    for (i in seq_along(other_settings)) {
      cat(sprintf("\t%s:\t%s\n", settings_names[i], other_settings[[i]]))
    }
  }

  cat("\n")
  return(invisible(x))
}
