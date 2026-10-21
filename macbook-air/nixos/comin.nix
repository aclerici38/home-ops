_: {
  services.comin = {
    enable = true;
    repositorySubdir = "macbook-air";
    remotes = [
      {
        name = "origin";
        url = "https://github.com/aclerici38/home-ops.git";
        poller.period = 3600;
        branches.main.name = "main";
      }
    ];
  };
}
