// adapted from https://medium.com/@karenmarkosyan/how-to-manage-promises-into-dynamic-queue-with-vanilla-javascript-9d0d1f8d4df5
export class Queue {
    private queue = new Array()
    private workingOnPromise = false;


    public enqueue(promise: () => Promise<any>) {
        return new Promise((resolve, reject) => {
            this.queue.push({
                promise,
                resolve,
                reject,
            });
            this.dequeue();
        });
    }

    private dequeue() {
        if (this.workingOnPromise) {
            console.log("Rejecting, promise pending")
            return;
        }
        const item = this.queue.shift();
        if (!item) {
            return;
        }

        try {
            this.workingOnPromise = true;
            item.promise()
                .then((value: any) => {
                    item.resolve(value);
                    console.log("Promise resolved")
                    this.workingOnPromise = false;
                    this.dequeue();
                })
                .catch((err: any) => {
                    item.reject(err);
                    console.log("Promise rejcted")
                    this.workingOnPromise = false;
                    this.dequeue();
                })
        } catch (err) {
            console.log("Promise threw")
            item.reject(err);
            this.workingOnPromise = false;
            this.dequeue();
        }
        return true;
    }
}