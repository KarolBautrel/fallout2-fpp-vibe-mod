cmake_minimum_required(VERSION 3.20)

project(fallout2_fpp_bridge_contract LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED YES)
set(CMAKE_CXX_EXTENSIONS NO)

if(NOT DEFINED FALLOUT2_CE_SOURCE_DIR)
    message(FATAL_ERROR "FALLOUT2_CE_SOURCE_DIR must point to a fallout2-ce checkout")
endif()

add_executable(fallout2_fpp_bridge_contract
    "bridge_contract_test.cc"
    "../src/fpp_bridge.cc"
)

target_include_directories(fallout2_fpp_bridge_contract PRIVATE
    "../src"
    "${FALLOUT2_CE_SOURCE_DIR}/src"
)
