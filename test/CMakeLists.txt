# Geary build script
# Copyright 2016 Software Freedom Conservancy Inc.
# Copyright 2016 Michael Gratton <mike@vee.net>

set(TEST_LIB_SRC
  mock-object.vala
  test-case.vala
)

set(TEST_ENGINE_SRC
  test-engine.vala

  # These should be included in the test lib sources, but we can't
  # since that would make the test lib depend on geary-engine.vapi,
  # and the engine test sute needs to depend
  # geary-engine_internal.vapi, which leads to duplicate symbols when
  # linking
  engine/api/geary-account-mock.vala
  engine/api/geary-email-identifier-mock.vala
  engine/api/geary-email-properties-mock.vala
  engine/api/geary-folder-mock.vala
  engine/api/geary-folder-path-mock.vala

  engine/api/geary-attachment-test.vala
  engine/api/geary-engine-test.vala
  engine/app/app-conversation-test.vala
  engine/app/app-conversation-monitor-test.vala
  engine/app/app-conversation-set-test.vala
  engine/imap/command/imap-create-command-test.vala
  engine/imap/response/imap-namespace-response-test.vala
  engine/imap/transport/imap-deserializer-test.vala
  engine/imap-engine/account-processor-test.vala
  engine/mime-content-type-test.vala
  engine/rfc822-mailbox-address-test.vala
  engine/rfc822-mailbox-addresses-test.vala
  engine/rfc822-message-test.vala
  engine/rfc822-message-data-test.vala
  engine/rfc822-utils-test.vala
  engine/util-html-test.vala
  engine/util-idle-manager-test.vala
  engine/util-inet-test.vala
  engine/util-js-test.vala
  engine/util-string-test.vala
  engine/util-timeout-manager-test.vala
)

set(TEST_CLIENT_SRC
  test-client.vala

  client/application/geary-configuration-test.vala
  client/components/client-web-view-test.vala
  client/components/client-web-view-test-case.vala
  client/composer/composer-web-view-test.vala

  js/client-page-state-test.vala
  js/composer-page-state-test.vala
  js/conversation-page-state-test.vala
)

# Vala
find_package(Vala REQUIRED)
include(ValaVersion)
include(ValaPrecompile)

pkg_check_modules(DEPS REQUIRED
  gee-0.8
  gio-2.0
  glib-2.0
  gmime-2.6
  gthread-2.0
  gtk+-3.0
  javascriptcoregtk-4.0
  libsoup-2.4
  webkit2gtk-4.0
  libxml-2.0
)

set(TEST_LIB_PACKAGES
  gee-0.8
  gio-2.0
  glib-2.0
)

set(TEST_ENGINE_PACKAGES
  gee-0.8
  gio-2.0
  glib-2.0
  gmime-2.6
  javascriptcore-4.0
  libunwind
  libxml-2.0
  sqlite3
)

set(TEST_CLIENT_PACKAGES
  gtk+-3.0
  libsoup-2.4
  webkit2gtk-4.0
)

set(CFLAGS
    ${DEPS_CFLAGS}
    ${DEPS_CFLAGS_OTHER}
    -D_BUILD_ROOT_DIR=\"${CMAKE_BINARY_DIR}\"
    -D_GSETTINGS_DIR=\"${CMAKE_BINARY_DIR}/gsettings\"
    -D_SOURCE_ROOT_DIR=\"${CMAKE_SOURCE_DIR}\"
)

include_directories(${CMAKE_BINARY_DIR}/src)

set(LIB_PATHS ${DEPS_LIBRARY_DIRS})

link_directories(${LIB_PATHS})
add_definitions(${CFLAGS})

# GResources must be compiled into the binary??
set_property(SOURCE ${RESOURCES_C} PROPERTY GENERATED TRUE)

set(VALAC_OPTIONS
    --vapidir=${CMAKE_BINARY_DIR}/src
    --vapidir=${CMAKE_BINARY_DIR}/test
    --vapidir=${CMAKE_SOURCE_DIR}/bindings/vapi
    --metadatadir=${CMAKE_SOURCE_DIR}/bindings/metadata
    --target-glib=${TARGET_GLIB}
    --thread
    --debug
    --enable-checking
    --enable-deprecated
    --fatal-warnings
    ${EXTRA_VALA_OPTIONS}
)

vala_precompile(TEST_LIB_VALA_C test-lib
    ${TEST_LIB_SRC}
PACKAGES
    ${TEST_LIB_PACKAGES}
OPTIONS
    --header=test-lib.h
    --vapi=test-lib.vapi
    ${VALAC_OPTIONS}
)

add_library(test-lib STATIC ${TEST_LIB_VALA_C})

vala_precompile(TEST_ENGINE_VALA_C test-engine
    ${TEST_ENGINE_SRC}
PACKAGES
    geary-engine-internal
    test-lib
    ${TEST_ENGINE_PACKAGES}
OPTIONS
    ${VALAC_OPTIONS}
)

vala_precompile(TEST_CLIENT_VALA_C test-client
    ${TEST_CLIENT_SRC}
PACKAGES
    geary-client
    geary-engine
    test-lib
    ${TEST_ENGINE_PACKAGES}
    ${TEST_CLIENT_PACKAGES}
OPTIONS
    ${VALAC_OPTIONS}
)

# Exclude from all so tests aren't built by default
add_executable(test-engine EXCLUDE_FROM_ALL ${TEST_ENGINE_VALA_C})
target_link_libraries(test-engine ${DEPS_LIBRARIES} geary-engine test-lib)

# Exclude from all so tests aren't built by default
add_executable(test-client EXCLUDE_FROM_ALL ${TEST_CLIENT_VALA_C} ${RESOURCES_C})
target_link_libraries(test-client ${DEPS_LIBRARIES} geary-client geary-engine test-lib)
