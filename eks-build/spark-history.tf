locals {

sparkhistorysrvr =<<SPHISTORY

kind: ConfigMap
apiVersion: v1
metadata:
  name: spark-history-server-config
data:
  spark-defaults.conf: |-
    spark.hadoop.fs.s3a.aws.credentials.provider=com.amazonaws.auth.WebIdentityTokenCredentialsProvider
    spark.history.fs.eventLog.rolling.maxFilesToRetain=5
---
apiVersion: v1
kind: Service
metadata:
  name: spark-history-server
  labels:
    app.kubernetes.io/name: spark-history-server
    app.kubernetes.io/instance: RELEASE-NAME
    app.kubernetes.io/version: "3.0.1"
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: 18080
    protocol: TCP
    name: spark-history-server
  selector:
      app.kubernetes.io/name: spark-history-server
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: spark-history-server
  labels:
    app.kubernetes.io/name: spark-history-server
    app.kubernetes.io/version: "3.0.1"
spec:
  replicas: 2
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 50%
      maxSurge: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: spark-history-server
  template:
    metadata:
      labels:
        app.kubernetes.io/name: spark-history-server
    spec:
      serviceAccountName: ${var.application-serviceaccount}
      automountServiceAccountToken: false
      containers:
      - name: spark-history-server
        image: "${var.spark-hs-image}"
        imagePullPolicy: Always
        command:
          - '/opt/spark/sbin/start-history-server.sh'
        env:
          - name: SPARK_NO_DAEMONIZE
            value: "false"
          - name: SPARK_HISTORY_OPTS
            value: "-Dspark.history.fs.logDirectory=${var.spark-hs-location}"
          - name: AWS_ROLE_SESSION_NAME
            value: "spark-hs"
          - name: SPARK_CONF_DIR
            value: /opt/spark/conf
        volumeMounts:
          - name: config-volume
            mountPath: /opt/spark/conf/spark-defaults.conf
            subPath: spark-defaults.conf
        ports:
          - name: http
            containerPort: 18080
            protocol: TCP
        terminationMessagePath: /dev/termination-log
        terminationMessagePolicy: File
        resources:
            limits:
              cpu: 2000m
              memory: 4096Mi
            requests:
              cpu: 250m
              memory: 512Mi
      volumes:
        - name: config-volume
          configMap:
            name: spark-history-server-config
---
apiVersion: networking.k8s.io/v1beta1
kind: Ingress
metadata:
  name: spark-history-server
  labels:
    app: spark-history-server
  annotations:
    kubernetes.io/ingress.class: nginx
spec:
  rules:
    - host: spark.eks-dm-dev.datamarvels.com
      http:
        paths:
          - path: /
            backend:
              serviceName: spark-history-server
              servicePort: 80
SPHISTORY

}

resource "local_file" "sparkhistorysrvc" {
  content = local.sparkhistorysrvr
  filename = "output/spark-history-srvr.yaml"
  file_permission = 0755
}


