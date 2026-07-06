_: {
  services.comin = {
    enable = true;
    repositorySubdir = "raphael";
    remotes = [
      {
        name = "origin";
        url = "https://github.com/aclerici38/home-ops.git";
        poller.period = 90;
        branches.main.name = "raphael-deploy";
      }
    ];
  };
}
