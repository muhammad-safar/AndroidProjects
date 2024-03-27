package com.nusabyte.app.apcc;

import com.nusabyte.app.apcc.tool.Connector;
import com.nusabyte.app.apcc.tool.HttpConnector;

import android.app.Activity;
import android.os.Bundle;
import android.widget.TextView;

public class MainActivity extends Activity
{
    @Override
    protected void onCreate(Bundle savedInstanceState)
    {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
        TextView text = (TextView) findViewById(R.id.my_text);
        text.setText("Hello World !");

        Connector connector = new HttpConnector(ACCESSIBILITY_SERVICE, BIND_IMPORTANT);
        connector.connect();
    }
}
