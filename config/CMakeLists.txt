include(ProjectVariable)

project_variable(CONFIG_DIR config CONFIG
  DOCSTRING "Directory containing configuration files")

if (WANT_UPS)
  add_subdirectory(ups)
endif()
