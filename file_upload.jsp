<%@ page import="org.apache.commons.fileupload.*, org.apache.commons.fileupload.servlet.ServletFileUpload, org.apache.commons.fileupload.disk.DiskFileItemFactory, org.apache.commons.io.FilenameUtils, java.util.*, java.io.*, java.lang.Exception, java.util.zip.*" %>
<%!
  protected SortedSet dirsMade;
  static int BUFFERSIZE = 2048;
  // Does this pathname point to a valid target directory? Should be
  // a subdir of the webapp. 
  boolean isValidSubdir(String path) {
    try {
        String canonical = (new File(path)).getCanonicalPath();
        String webapp =  (new File((getServletContext().getRealPath(".")))).getCanonicalPath();
      return canonical.startsWith(webapp);
    } catch (IOException e) {
      return false;
    }
  }

  public static final void copyInputStream(InputStream in, OutputStream out) throws IOException {
    byte[] buffer = new byte[BUFFERSIZE];
    int len;

    while((len = in.read(buffer)) >= 0)
      out.write(buffer, 0, len);

    in.close();
    out.close();
  }
%>
<%
// maximum size of zipfile to accept, in bytes
int maxSize = 1024 * 1024 * 5;
// directory to write into, without trailing slash
String basedir = "/my-apps";
// session UID to append, if not passed in 'uid' field
String sessionId = "tmp_" + session.getId();

String path = null;
try {
    // Should be $LPS_HOME
    path = (new File((getServletContext().getRealPath(".")))).getCanonicalPath();
} catch (Exception e){
    out.println("JSP error caught: "+e);
    return;
}

if (ServletFileUpload.isMultipartContent(request)){
  ServletFileUpload servletFileUpload = new ServletFileUpload(new DiskFileItemFactory());
  List fileItemsList = servletFileUpload.parseRequest(request);

  String optionalFileName = "";
  String optionalSessionID = "";
  FileItem fileItem = null;

  Iterator it = fileItemsList.iterator();
  while (it.hasNext()){
    FileItem fileItemTemp = (FileItem)it.next();
    if (fileItemTemp.isFormField()){
      if (fileItemTemp.getFieldName().equals("filename")) {
        optionalFileName = fileItemTemp.getString();
      } else if (fileItemTemp.getFieldName().equals("uid")) {
        optionalSessionID = fileItemTemp.getString();    
      }
    } else {
      fileItem = fileItemTemp;
    }
  }

  if (! optionalSessionID.trim().equals("")) {
     sessionId = optionalSessionID;
  }

  // Create full path
  path += basedir + "/" + sessionId + "/";
  if (!isValidSubdir(path)) {
      out.println("Invalid path.");
      return;
  }

  // create temp dir
  (new File(path)).mkdir();

  if (fileItem!=null){
    String fileName = fileItem.getName();

    /* Save the uploaded file if its size is between 0 and maxSize, and it's a zip file. */
    if (fileItem.getSize() > 0 && fileItem.getSize() < maxSize && fileItem.getContentType().equals("application/zip")){
      if (optionalFileName.trim().equals("")) {
        fileName = FilenameUtils.getName(fileName);
      } else {
        fileName = optionalFileName;
      }

      if (!isValidSubdir(path + fileName)) {
        out.println("Invalid path.");
        return;
      }

      File saveTo = new File(path + fileName);
      try {
        // write out zip file
        fileItem.write(saveTo);

        // unzip the file
        ZipFile zipFile = new ZipFile(saveTo);

        Enumeration entries = zipFile.entries();
        ZipEntry entry;

        BufferedInputStream zipin = null;
        BufferedOutputStream zipout = null;
        dirsMade = new TreeSet();

        while(entries.hasMoreElements()) {
          entry = (ZipEntry)entries.nextElement();
          String entryname = entry.getName();
          if (!isValidSubdir(path + entryname)) {
            out.println("Invalid path.");
            return;
          }

          if (entryname.startsWith("/")) {
            entryname = entryname.substring(1);
          }
          if (entryname.endsWith("/")) {
            continue;
          }

          int ix = entryname.lastIndexOf('/');
          if (ix > 0) {
            String dirName = path + entryname.substring(0, ix);
            if (!dirsMade.contains(dirName)) {
              File d = new File(dirName);
              if (!(d.exists() && d.isDirectory())) {
                if (!d.mkdirs()) {
                }
                dirsMade.add(dirName);
              }
            }
          }

          //System.out.println("Extracting file: " + entryname);
          zipin = new BufferedInputStream (zipFile.getInputStream(entry));
          FileOutputStream fos = new FileOutputStream(path + entryname);
          zipout = new BufferedOutputStream(fos, BUFFERSIZE);
          copyInputStream(zipin, zipout);
        }

        zipFile.close();
        response.setHeader("X-Path-UID", sessionId);
%>
<%= sessionId %>
<%
      }
      catch (Exception e){
%>
An error occurred.
<%
      }
    }
  }
}
%>
