package app.surveycontour.survey_contour_generator

import android.os.Bundle
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Edge-to-edge: the Flutter UI draws behind the system bars and handles insets itself.
        WindowCompat.setDecorFitsSystemWindows(window, false)
    }
}
