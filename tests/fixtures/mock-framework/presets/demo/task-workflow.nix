# Export + compose mock-cpu tasks into a tiny workflow around demo:build.
{ tools, ... }:
{
  path = [
    "demo"
    "task-workflow"
  ];
  description = "Mock preset that exports tool tasks and composes a workflow.";
  categoryPolicy = false;
  defaultEnable = false;
  when = _: true;
  exportTasks = [ tools.profilers.cpu.mock-cpu ];
  workflows = [
    {
      around = "demo:build";
      before = [ "mock-cpu:sample" ];
      after = [ "mock-cpu:report" ];
    }
  ];
  project = { };
}
