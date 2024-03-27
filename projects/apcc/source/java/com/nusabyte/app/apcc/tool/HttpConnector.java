package com.nusabyte.app.apcc.tool;

public class HttpConnector
    implements Connector
{
    public final String ipAddress;
    public final int port; 

    public HttpConnector(String ipAddress, int port)
    {
        this.ipAddress = ipAddress;
        this.port = port;
    }

    @Override
    public void connect()
    {
        // TODO
    }
}
