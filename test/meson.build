geary_test_lib_sources = [
  'mock-object.vala',
  'test-case.vala',
]

geary_test_engine_sources = [
  'test-engine.vala',

  # These should be included in the test lib sources, but we can't
  # since that would make the test lib depend on geary-engine.vapi,
  # and the engine test sute needs to depend
  # geary-engine_internal.vapi, which leads to duplicate symbols when
  # linking
  'engine/api/geary-account-mock.vala',
  'engine/api/geary-email-identifier-mock.vala',
  'engine/api/geary-email-properties-mock.vala',
  'engine/api/geary-folder-mock.vala',
  'engine/api/geary-folder-path-mock.vala',

  'engine/api/geary-attachment-test.vala',
  'engine/api/geary-engine-test.vala',
  'engine/app/app-conversation-test.vala',
  'engine/app/app-conversation-monitor-test.vala',
  'engine/app/app-conversation-set-test.vala',
  'engine/imap/command/imap-create-command-test.vala',
  'engine/imap/response/imap-namespace-response-test.vala',
  'engine/imap/transport/imap-deserializer-test.vala',
  'engine/imap-engine/account-processor-test.vala',
  'engine/mime-content-type-test.vala',
  'engine/rfc822-mailbox-address-test.vala',
  'engine/rfc822-mailbox-addresses-test.vala',
  'engine/rfc822-message-test.vala',
  'engine/rfc822-message-data-test.vala',
  'engine/rfc822-utils-test.vala',
  'engine/util-html-test.vala',
  'engine/util-idle-manager-test.vala',
  'engine/util-inet-test.vala',
  'engine/util-js-test.vala',
  'engine/util-string-test.vala',
  'engine/util-timeout-manager-test.vala'
]

geary_test_client_sources = [
  'test-client.vala',

  'client/application/geary-configuration-test.vala',
  'client/components/client-web-view-test.vala',
  'client/components/client-web-view-test-case.vala',
  'client/composer/composer-web-view-test.vala',

  'js/client-page-state-test.vala',
  'js/composer-page-state-test.vala',
  'js/conversation-page-state-test.vala',

  geary_compiled_schema,
  geary_resources
]

geary_test_lib_dependencies = [
  gee,
  gio,
  glib
]

geary_test_engine_dependencies = [
  geary_engine_internal_dep
]
geary_test_engine_dependencies += geary_engine_dependencies

geary_test_client_dependencies = [
  geary_client_dep
]
geary_test_client_dependencies += geary_client_dependencies

geary_test_lib = static_library('geary-test-lib',
  geary_test_lib_sources,
  dependencies: geary_test_lib_dependencies,
  include_directories: config_h_dir,
  vala_args: geary_vala_options,
  c_args: geary_c_options,
)

geary_test_engine_bin = executable('geary-test-engine',
  geary_test_engine_sources,
  link_with: geary_test_lib,
  dependencies: geary_test_engine_dependencies,
  include_directories: config_h_dir,
  vala_args: geary_vala_options,
  c_args: geary_c_options,
)

geary_test_client_bin = executable('geary-test-client',
  geary_test_client_sources,
  dependencies: geary_test_client_dependencies,
  link_with: geary_test_lib,
  include_directories: config_h_dir,
  vala_args: geary_vala_options,
  c_args: geary_c_options,
)

test('engine-tests', geary_test_engine_bin)
test('client-tests', geary_test_client_bin)
