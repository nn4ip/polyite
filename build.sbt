ThisBuild / scalaVersion	:= "2.11.6"

lazy val polyite = (project in file("."))
  .dependsOn(isl, chernikova)
  .settings(
    name := "polyite"
  )

lazy val isl = (project in file("scala-isl-utils"))
  .settings(
    name := "isl"
  )

lazy val chernikova = (project in file("chernikova"))
  .dependsOn(isl)
  .settings(
    name := "chernikova"
  )
