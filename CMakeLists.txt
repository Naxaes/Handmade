# Only used for debugging in CLion
cmake_minimum_required(VERSION 3.10.0)

add_custom_command(
    OUTPUT  app_run.txt
    COMMAND /bin/echo "Not building!"
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
)

add_custom_target(app_run ALL DEPENDS app_run.txt)