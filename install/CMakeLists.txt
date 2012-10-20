# --------------------------------------------------------------
#  /Applications/Lubyk/Lubyk.app
# --------------------------------------------------------------
if(APPLE)
  install(DIRECTORY ${PLAT}/Lubyk.app
    DESTINATION /Applications
  )
  install(FILES ${PLAT}/Lubyk.app/Contents/MacOS/Lubyk
    DESTINATION /Applications/Lubyk.app/Contents/MacOS
    PERMISSIONS OWNER_READ OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)

  install(DIRECTORY ${PLAT}/InstallLubyk.app
    DESTINATION ${LUBYK_LIB}/lib
  )

  install(FILES ${PLAT}/InstallLubyk.app/Contents/MacOS/applet
    DESTINATION ${LUBYK_LIB}/lib/InstallLubyk.app/Contents/MacOS
    PERMISSIONS OWNER_READ OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)
endif(APPLE)

