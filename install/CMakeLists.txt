# --------------------------------------------------------------
#  /Applications/Lubyk/Lubyk.app
# --------------------------------------------------------------
if(APPLE)
  install(DIRECTORY macosx/Lubyk.app
    DESTINATION /Applications
  )
  install(FILES macosx/Lubyk.app/Contents/MacOS/Lubyk
    DESTINATION /Applications/Lubyk.app/Contents/MacOS
    PERMISSIONS OWNER_READ OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)
endif(APPLE)
