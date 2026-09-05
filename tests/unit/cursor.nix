{ project, ... }:
{
  testCursorUnwantedWhenLanguagesOff = {
    expr = project.cursorUnwanted { };
    expected =
      project.cursorLanguageIds.rust
      ++ project.cursorLanguageIds.go
      ++ project.cursorLanguageIds.python
      ++ project.cursorLanguageIds.typescript;
  };

  testCursorRecommendationsPython = {
    expr = project.cursorRecommendations { python.enable = true; };
    expected = project.cursorAlwaysRecommend ++ project.cursorLanguageIds.python;
  };

  testCursorRecommendationsJavascriptOrTypescript = {
    expr = [
      (project.cursorRecommendations { javascript.enable = true; })
      (project.cursorRecommendations { typescript.enable = true; })
    ];
    expected = [
      (project.cursorAlwaysRecommend ++ project.cursorLanguageIds.typescript)
      (project.cursorAlwaysRecommend ++ project.cursorLanguageIds.typescript)
    ];
  };
}
