FROM ibmcom/swift-ubuntu-runtime:latest

ENV RESOURCES /EasyLoginServer/Resources

EXPOSE 8080

COPY Server/.build/x86_64-unknown-linux/release/EasyLogin /EasyLoginServer/EasyLogin
COPY Server/Resources $RESOURCES

CMD /EasyLoginServer/EasyLogin
