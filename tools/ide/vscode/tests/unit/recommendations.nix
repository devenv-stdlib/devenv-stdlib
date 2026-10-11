{ project, ... }:
{
  testVscodeUnwantedWhenLanguagesOff = {
    expr = project.vscodeUnwanted { };
    expected =
      project.vscodeLanguageIds.rust
      ++ project.vscodeLanguageIds.go
      ++ project.vscodeLanguageIds.python
      ++ project.vscodeLanguageIds.typescript;
  };

  testVscodeRecommendationsPython = {
    expr = project.vscodeRecommendations { python.enable = true; };
    expected = project.vscodeAlwaysRecommend ++ project.vscodeLanguageIds.python;
  };

  testVscodeRecommendationsJavascriptOrTypescript = {
    expr = [
      (project.vscodeRecommendations { javascript.enable = true; })
      (project.vscodeRecommendations { typescript.enable = true; })
    ];
    expected = [
      (project.vscodeAlwaysRecommend ++ project.vscodeLanguageIds.typescript)
      (project.vscodeAlwaysRecommend ++ project.vscodeLanguageIds.typescript)
    ];
  };
}
