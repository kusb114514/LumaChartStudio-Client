using LumaChart.iOS.Platform;
using UIKit;

namespace LumaChart.iOS;

public static class Application
{
    private static void Main(string[] args)
    {
        // A module initializer has already installed the log by this point; the
        // call is idempotent and only matters if module initializers were not
        // honoured. Reaching this line at all is itself the evidence that
        // managed startup ran.
        IOSLaunchLog.Install("Main");
        IOSLaunchLog.Write("Main: entering UIApplication.Main");

        try
        {
            UIApplication.Main(args, null, typeof(AppDelegate));
        }
        catch (Exception exception)
        {
            IOSLaunchLog.WriteException("UIApplication.Main", exception);
            throw;
        }
    }
}
