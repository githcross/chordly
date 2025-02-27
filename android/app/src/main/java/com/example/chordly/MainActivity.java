import io.flutter.embedding.android.FlutterActivity;
import android.os.Bundle;
import android.os.Process;

public class MainActivity extends FlutterActivity {
    @Override
    protected void onResume() {
        super.onResume();
        Process.setThreadPriority(Process.THREAD_PRIORITY_URGENT_AUDIO);
    }
} 